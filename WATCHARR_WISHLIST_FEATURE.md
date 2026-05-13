# Liste d'envies (proxy Watcharr)

Récap de la feature à implémenter côté backend.

## Idée

Exposer dans Kidflix une liste « à voir » alimentée par une instance
[Watcharr](https://github.com/sbondCo/Watcharr) auto-hébergée
(gestionnaire de watchlist communautaire pour films/séries, basé sur
TMDB). L'objectif côté famille : tenir une seule liste d'envies dans
Watcharr et la consulter — et l'**enrichir** — depuis Kidflix, avec un
flag « déjà disponible dans la médiathèque » par item.

La feature est **réservée au profil principal** (`is_main = true`) :
montrer aux enfants des films indisponibles serait frustrant, et la
wishlist est par nature une décision parent.

L'app cliente **ne parle jamais directement** à l'instance Watcharr.
Tout transite par kidflix-api (cohérent avec le proxy Infomaniak pour
les downloads, cf. `API.md § Téléchargement de fichier vidéo`).

Côté Flutter, l'app expose :

- Une page « Liste d'envies » accessible depuis le menu avatar de la
  home (visible uniquement pour le profil principal). Elle affiche les
  films **et** séries dont le statut est `PLANNED` et qui ne sont pas
  encore dans le catalogue local — sortis alphabétiquement.
- Un bouton flottant « Ajouter » ouvrant une page de recherche TMDB
  (déléguée à Watcharr) avec ajout direct à la liste.
- Long-press sur une carte → bottom sheet « Marquer comme vu »
  (= statut `FINISHED`) ou « Retirer de la liste » (DELETE).

## Backend

### Configuration

Une seule variable d'environnement globale :

| Var                  | Exemple                  | Sens                                                  |
| -------------------- | ------------------------ | ----------------------------------------------------- |
| `WATCHARR_BASE_URL`  | `http://watcharr:3080`   | URL interne de l'instance Watcharr (LAN / Docker net) |

**Credentials Watcharr : un compte par numéro de téléphone Kidflix.**
Chaque utilisateur Kidflix (identifié par son `phone_number`) a son
propre compte Watcharr — les listes d'envies sont donc séparées par
foyer / numéro. La notion de profil Kidflix (papa, maman, kids sous le
même numéro) ne mappe **pas** sur des comptes Watcharr distincts : tous
les profils du numéro partagent la même wishlist familiale (cf. § Hors
scope pour une version par-profil).

### Schéma — credentials Watcharr par utilisateur

Une table dédiée pour stocker la liaison `kidflix_user ↔ watcharr_user` :

```sql
CREATE TABLE user_watcharr_credentials (
  user_id            UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  watcharr_username  TEXT NOT NULL,
  watcharr_password  TEXT NOT NULL,  -- chiffré au repos
  watcharr_jwt       TEXT,           -- cache du dernier JWT obtenu (nullable)
  watcharr_jwt_iat   TIMESTAMPTZ,    -- "issued at" du JWT en cache (nullable)
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- `watcharr_password` chiffré au repos (clé applicative / vault / env
  secret). Watcharr n'expose pas d'API key durable → il faut pouvoir
  re-login, donc un secret réversible côté kidflix-api.
- `watcharr_jwt` / `watcharr_jwt_iat` : cache facultatif pour éviter un
  login par requête. Sur 401 amont → re-login + UPDATE.

**Provisioning** : hors-scope. L'admin crée le compte Watcharr puis
insère la row à la main (ou via un endpoint admin). Si la row manque
pour un `user_id` donné, les routes `/wishlist*` renvoient
`503 wishlist_not_configured` — l'app cliente masque alors gracieusement
l'entrée du menu.

### Index nécessaires

```sql
CREATE INDEX IF NOT EXISTS idx_movies_tmdb_id ON movies (tmdb_id);
CREATE INDEX IF NOT EXISTS idx_series_tmdb_id ON series (tmdb_id);
```

Requis pour le croisement TMDB → catalogue local sur `GET /wishlist`
et `GET /wishlist/search`.

### Auth amont (Watcharr)

Watcharr n'expose pas d'API key durable. Pour **chaque** requête
`/wishlist*`, le serveur kidflix-api doit :

1. Résoudre le `user_id` depuis le JWT Kidflix.
2. Lire `user_watcharr_credentials` pour cet `user_id`. Absent →
   `503 wishlist_not_configured`.
3. Si `watcharr_jwt` est en cache → l'utiliser. Sinon, faire
   `POST {WATCHARR_BASE_URL}/api/auth/` avec `{username, password}`,
   stocker le JWT en cache (`UPDATE user_watcharr_credentials`).
4. Appeler l'endpoint Watcharr cible avec le JWT dans le header
   `Authorization` **sans préfixe `Bearer`** (spécificité Watcharr —
   c'est le token brut, sinon 401).
5. Sur réponse 401 d'un endpoint Watcharr → re-login automatique (étape
   3 forcée), retry une fois. Si le retry échoue →
   `502 watcharr_unavailable`.

### Conventions

- Toutes les routes `/wishlist*` exigent les headers existants
  (`Authorization: Bearer <jwt-kidflix>`, `X-Device-Id`,
  `X-Profile-Id`) avec en plus la garde `is_main = true`
  (sinon `403 main_profile_required`).
- Format JSON UTF-8, casing `snake_case` côté wire.
- Le client n'envoie **jamais** `kind: "tv"` à kidflix-api — c'est
  toujours `"movie"` ou `"series"`. La traduction vers le vocabulaire
  Watcharr (`tv` côté `POST /api/watched`) est faite côté serveur (cf.
  §POST /wishlist).

### `GET /wishlist`

Renvoie toutes les entrées de la watchlist Watcharr, enrichies du
croisement avec le catalogue Kidflix.

**Appel amont** : `GET {WATCHARR_BASE_URL}/api/watched` (paginé,
itérer toutes les pages côté serveur — volume famille < 200).

**Filtrage amont** :

- Exclure les entrées dont `content.type` n'est pas dans `{movie, tv}`
  (Watcharr supporte aussi `tv_episode` et `game` — hors scope).
- Exclure les entrées dont `content.tmdbId` est `null` (entrées
  manuelles Watcharr non liées à TMDB).
- Conserver **tous les statuts** (`PLANNED`, `WATCHING`, `HOLD`,
  `FINISHED`, `DROPPED`) — le client filtre côté UI.

**Croisement catalogue** : pour chaque entrée conservée,

```sql
-- content.type = "movie"
SELECT id FROM movies
  WHERE tmdb_id = :tmdbId AND deleted_at IS NULL
  LIMIT 1;

-- content.type = "tv"
SELECT id FROM series
  WHERE tmdb_id = :tmdbId AND deleted_at IS NULL
  LIMIT 1;
```

Match → `available_in_catalog: true`, `catalog_id: "<id>"`,
`catalog_kind: "movie" | "series"`.
Pas de match → `available_in_catalog: false`, `catalog_id: null`,
`catalog_kind: null`.

Le croisement **n'applique pas** le filtre âge du profil actif : le
profil principal est `adulte`, il voit tout le catalogue.

**Response 200**

```json
{
  "items": [
    {
      "watcharr_id": 42,
      "tmdb_id": 1399,
      "kind": "series",
      "title": "Game of Thrones",
      "year": 2011,
      "poster_url": "https://image.tmdb.org/t/p/w500/u3bZgnGQ9T01sWNhyveQz0wH0Hl.jpg",
      "status": "PLANNED",
      "rating": 0,
      "available_in_catalog": false,
      "catalog_kind": null,
      "catalog_id": null
    },
    {
      "watcharr_id": 87,
      "tmdb_id": 22,
      "kind": "movie",
      "title": "Pirates des Caraïbes : La Malédiction du Black Pearl",
      "year": 2003,
      "poster_url": "https://image.tmdb.org/t/p/w500/k6F5MQzN3WFolXcS9bdW1ZUaPxq.jpg",
      "status": "PLANNED",
      "rating": 0,
      "available_in_catalog": true,
      "catalog_kind": "movie",
      "catalog_id": "pirates-caraibes-black-pearl"
    }
  ]
}
```

**Mapping de champs (Watcharr → Kidflix)**

- `id` → `watcharr_id` (entier, identifiant interne Watcharr requis
  pour les mutations)
- `content.tmdbId` → `tmdb_id`
- `content.type` → `kind` (`movie` reste `movie`, `tv` devient
  `series`)
- `content.title` → `title`
- `content.release_date` (ISO `YYYY-MM-DD`) → `year` (entier, parsing
  côté serveur ; `null` si parsing échoue)
- `content.poster_path` → `poster_url` (préfixer avec
  `https://image.tmdb.org/t/p/w500` ; `null` si `poster_path` null)
- `status` → `status` (string brute, enum
  `PLANNED | WATCHING | FINISHED | HOLD | DROPPED`)
- `rating` → `rating` (entier 0-10, 0 = non noté)

Header de cache : `cache-control: private, max-age=30`.

### `GET /wishlist/search?q={q}`

Recherche TMDB déléguée à Watcharr, normalisée pour l'app cliente.

**Query**

- `q` (requis) : `q.trim().length >= 2`, sinon `400 invalid_request`.

**Appel amont** :
`GET {WATCHARR_BASE_URL}/api/search?query={q}&type=multi&page=1`.

**Filtrage amont** :

- Exclure les entrées dont `type` n'est pas dans `{tmdb_movie, tmdb_tv}`
  (filtre `tmdb_person`, `igdb_game` etc.).
- Exclure les entrées sans `ids.tmdb`.

**Croisement** :

- Catalogue : même JOIN que `/wishlist` pour
  `available_in_catalog` / `catalog_kind` / `catalog_id`.
- Wishlist : pour chaque résultat, lookup dans la watchlist Watcharr
  de l'utilisateur (peut être fait en un seul appel à `GET /api/watched`
  caché en mémoire pour la durée de la requête) → `already_in_wishlist`.

**Response 200**

```json
{
  "items": [
    {
      "tmdb_id": 27205,
      "kind": "movie",
      "title": "Inception",
      "year": 2010,
      "poster_url": "https://image.tmdb.org/t/p/w500/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
      "available_in_catalog": false,
      "catalog_kind": null,
      "catalog_id": null,
      "already_in_wishlist": false
    }
  ]
}
```

**Mapping de champs (Watcharr → Kidflix)**

- `ids.tmdb` → `tmdb_id`
- `type` → `kind` : `tmdb_movie` → `movie`, `tmdb_tv` → `series`
- `name` → `title`
- `releaseDate` (ISO 8601 datetime) → `year` (entier, `null` si
  parsing échoue)
- `extPosterPath` → `poster_url` (préfixer avec
  `https://image.tmdb.org/t/p/w500` ; `null` si absent)

**Pagination** : v1 = première page Watcharr uniquement (~20 résultats),
suffisant pour le use case d'ajout famille. Pas de query param `page`
exposé côté API publique. À étendre si feedback usage.

**Notes** :

- Pas de tri imposé côté API publique — l'app cliente conserve l'ordre
  de pertinence renvoyé par Watcharr.
- Pas de cache HTTP (résultats dépendants du contenu Watcharr +
  catalogue local).

### `POST /wishlist`

Ajoute une entrée TMDB à la watchlist Watcharr avec statut `PLANNED`.

**Request body**

```json
{
  "tmdb_id": 27205,
  "kind": "movie"
}
```

`kind` accepte `"movie"` ou `"series"`. Autre valeur → `400 invalid_request`.

**Appel amont** :
`POST {WATCHARR_BASE_URL}/api/watched` body :

```json
{
  "tmdbId": 27205,
  "contentType": "movie",
  "status": "PLANNED"
}
```

⚠️ **Piège Watcharr** : `contentType` accepte `movie` | `tv` | `game`.
Pour une série, c'est **`tv`** (pas `show` comme dans le param de
search). Le mapping serveur-side est donc :

- `kind: "movie"` → `contentType: "movie"`
- `kind: "series"` → `contentType: "tv"`

**Response 200** — l'entrée créée, **même schéma qu'un item de
`GET /wishlist`** (re-fetcher au besoin pour la forme normalisée +
croisement catalogue, ou renvoyer la transformation locale).

**Erreurs spécifiques**

- `409 wishlist_entry_exists` quand Watcharr renvoie son
  `403 "watched entry exists"` (l'entrée est déjà dans la liste, quel
  que soit son statut, y compris soft-deleted). À noter : le code HTTP
  amont est `403` mais on **traduit en 409** côté kidflix-api pour
  éviter la confusion avec le `403 main_profile_required`.

### `PUT /wishlist/{watcharr_id}/status`

Change le statut d'une entrée (typiquement `PLANNED` → `FINISHED`).

**Request body**

```json
{ "status": "FINISHED" }
```

Statut accepté : `PLANNED | WATCHING | FINISHED | HOLD | DROPPED`.
Autre valeur → `400 invalid_request`.

**Appel amont** :
`PUT {WATCHARR_BASE_URL}/api/watched/:id` body
`{"status": "FINISHED"}`.

**Response 200** — l'entrée mise à jour (même schéma que
`GET /wishlist`, croisement catalogue refait).

### `DELETE /wishlist/{watcharr_id}`

Retire une entrée de la watchlist Watcharr.

**Appel amont** : `DELETE {WATCHARR_BASE_URL}/api/watched/:id`.

**Response 204**.

### Catalogue d'erreurs

| HTTP | `error.code`              | Quand                                                                                                          |
| ---- | ------------------------- | -------------------------------------------------------------------------------------------------------------- |
| 400  | `invalid_request`         | Body / query invalide (statut inconnu, `kind` invalide, `q` < 2 chars)                                         |
| 403  | `main_profile_required`   | `X-Profile-Id` ne pointe pas un profil principal                                                               |
| 404  | `not_found`               | `watcharr_id` inexistant côté Watcharr (404 amont propagé)                                                     |
| 409  | `wishlist_entry_exists`   | `POST /wishlist` sur une `(tmdb_id, kind)` déjà dans la liste (`403 watched entry exists` upstream, normalisé) |
| 502  | `watcharr_unavailable`    | API Watcharr injoignable, 5xx, ou 401 après retry                                                              |
| 503  | `wishlist_not_configured` | Pas de row `user_watcharr_credentials` pour le `user_id` du JWT (feature non activée pour ce foyer)            |

`watcharr_unavailable` est distinct de `bad_gateway` (réservé au proxy
Infomaniak) pour faciliter le tri côté logs / monitoring.

## App (Flutter) — déjà implémentée

L'app cliente est déjà câblée sur ces contrats (cf. commit
`feat(wishlist): "Liste d'envies" Watcharr-backed surface in home
menu`). Côté code :

- `lib/core/domain/services/wishlist.repository.dart` : 5 méthodes
  (`list`, `updateStatus`, `remove`, `search`, `add`).
- `lib/infrastructure/wishlist/dio.wishlist.repository.dart` :
  implémentation HTTP qui mappe `503 → WishlistNotConfiguredException`
  et `409 → WishlistEntryAlreadyExistsException`.
- En mode "in-memory base URL" (= empty / demo), un seed local est
  utilisé pour exercer la UI sans backend.

Aucune modif client requise une fois le backend déployé — le `Dio`
prend la base URL de la config (`apiBaseUrl`) et l'`AuthInterceptor`
injecte déjà les headers.

## Compatibilité

- Pas de modification d'endpoint existant. Aucun risque sur les
  clients déjà déployés.
- Le serveur kidflix-api doit gérer l'absence de configuration
  **gracieusement** : si `WATCHARR_BASE_URL` est vide / non défini, OU
  si l'utilisateur n'a pas de row `user_watcharr_credentials`, les
  cinq routes `/wishlist*` renvoient `503 wishlist_not_configured`.
  Permet de déployer le backend sans Watcharr et d'activer la feature
  numéro par numéro.

## Hors scope

- **Wishlist par-profil** : v1 = un compte Watcharr par
  `phone_number` Kidflix (donc partagé entre les profils du même
  foyer). Si besoin futur d'une wishlist personnelle par profil,
  étendre `user_watcharr_credentials` en `profile_watcharr_credentials`
  et router les appels par `X-Profile-Id`.
- **Pagination publique de search/list** : v1 → toute la liste sur
  `/wishlist`, première page Watcharr sur `/wishlist/search`. À
  ajouter si > 500 entrées en pratique ou si l'usage de la recherche
  appelle à scroller plus loin.
- **Webhook Watcharr → Kidflix** pour pousser une notif « ce film de
  ta wishlist vient d'arriver dans la médiathèque » : nécessiterait
  une intégration côté ingest scanner (`add-catalog`). Plus tard.
- **Synchronisation des notes Kidflix → Watcharr** (regarder un film
  dans Kidflix met à jour la wishlist en `FINISHED`) : possible via le
  `WatchProgressRepository` existant, mais nécessite un mapping
  inverse `catalog_id → tmdb_id → watcharr_id`. Plus tard.
- **Sélection du statut à l'ajout** : l'app n'expose que `PLANNED`
  comme statut d'ajout. Si le parent veut consigner un film
  déjà vu, il passe par Watcharr directement (ou via la mutation
  `PUT /wishlist/{id}/status` après création).
- **Ratings / thoughts / tags Watcharr** : non exposés côté Kidflix
  pour v1. Le parent les gère dans Watcharr.

## Décisions produit à confirmer avant déploiement

1. **Statut auto au visionnage** : si un kid lit un film présent dans
   la wishlist (croisement positif), faut-il auto-marquer `FINISHED`
   côté Watcharr ? Doc ci-dessus = non. À confirmer.
2. **TTL JWT Watcharr** : à observer en prod. Si trop court (< 1h),
   le cache `watcharr_jwt` côté `user_watcharr_credentials` suffit
   probablement, mais à valider.
3. **Comportement `available_in_catalog` à l'ajout** : si le parent
   ajoute un film déjà présent dans la médiathèque, l'app affiche
   « Déjà dans la médiathèque » dans les résultats de search mais
   permet quand même l'ajout. Doc côté API = idem (le serveur ne
   bloque pas). À confirmer.
