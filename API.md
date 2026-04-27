# API backend — contrat minimal

Cette doc décrit l'API HTTP **strictement nécessaire** pour remplacer les
implémentations in-memory des repositories de Kidflix par un vrai backend,
sans ajouter aucune feature qui n'existe pas déjà dans l'app cliente.

Source de vérité côté client : les interfaces dans `lib/core/domain/services/`
et leurs implémentations actuelles dans `lib/infrastructure/*/in_memory.*`.

---

## Vue d'ensemble — repository ↔ endpoint

| Repository client | Méthodes | Endpoints HTTP |
|---|---|---|
| `AuthRepository` | `requestOtp`, `verifyOtp` | `POST /auth/request-otp`, `POST /auth/verify-otp` |
| `CatalogRepository` | `listMoviesFor`, `searchMovies` | `GET /movies?age_category=…`, `GET /movies?search=…&up_to_age_category=…` |
| `DownloadRepository` | `download` (stream HTTP) | `GET /movies/{movie_id}/download` (Range supporté) |
| `ProfileManagementRepository` | `create`, `updateMetadata`, `setPin`, `clearPin`, `delete` | `POST /profiles`, `PATCH /profiles/{id}`, `PUT /profiles/{id}/pin`, `DELETE /profiles/{id}/pin`, `DELETE /profiles/{id}` |
| `WatchProgressRepository` | `findFor`, `save`, `listForProfile` | `GET /profiles/{profile_id}/progress/{movie_id}`, `PUT /profiles/{profile_id}/progress/{movie_id}`, `GET /profiles/{profile_id}/progress` |
| `SessionRepository` | — | _aucun_ (persistance 100 % locale ; le JWT consommé provient de `verifyOtp`) |

`DownloadRepository.findByMovieId`, `cancel` et `delete` sont **purement
locaux** (filesystem) côté client : ils n'impliquent pas le backend.

---

## Conventions

- **Base URL** : `https://api.kidflix.example` (à figer selon la config VPS).
- **Format** : JSON UTF-8 en requête et en réponse (`Content-Type:
  application/json`), à l'exception de `GET /movies/{id}/download` qui
  renvoie un flux binaire MP4.
- **Casing JSON** : `snake_case` pour les clés (`age_category`,
  `position_seconds`, `expires_at`).
- **Dates** : ISO 8601 / RFC 3339 en UTC (ex. `2026-04-22T10:30:00Z`).
- **Durées** : entiers en secondes (jamais ISO 8601 duration).
- **Énumérations transmises en string** :
  - `age_category` : `"bebe" | "enfant" | "ado" | "jeune_adulte" | "adulte"`
    (l'app sérialise déjà l'enum Dart par son `name`, attention à la
    convention `jeune_adulte` côté wire — voir [Mapping énum](#mapping-des-énumérations)).
- **Authentification** : header `Authorization: Bearer <jwt>` sur toutes
  les routes sauf `POST /auth/request-otp` et `POST /auth/verify-otp`.
- **Identifiant device** : header `X-Device-Id: <uuid>` sur toutes les
  routes authentifiées (le client génère et persiste cet UUID au premier
  lancement, comme aujourd'hui via `SessionRepository.readOrCreateDevice`).

### Format d'erreur

Toutes les erreurs renvoient un JSON :

```json
{ "error": { "code": "string_machine_readable", "message": "Texte humain optionnel" } }
```

Les codes machine consommés explicitement par le client sont listés dans
[Catalogue d'erreurs](#catalogue-derreurs). Tout autre code peut être
remonté tel quel mais sera traité comme erreur générique côté UI.

### Mapping des énumérations

L'enum Dart `AgeCategory` a la valeur `jeuneAdulte`. Le client la sérialise
via `.name`, donc en pratique il enverra et attendra **`jeuneAdulte`** sur
le wire tant que la sérialisation actuelle n'est pas modifiée.

**Décision attendue côté backend** : accepter `jeuneAdulte` (camelCase)
pour ne pas avoir à toucher l'app, OU exposer `jeune_adulte` et adapter
les DTO côté Flutter. Cette doc liste les deux endroits où la valeur
apparaît : `GET /movies` (paramètre + champ de réponse), et tous les
endpoints `/profiles/*` (champ `age_category`).

---

## Auth

### `POST /auth/request-otp`

Déclenche l'envoi d'un OTP par SMS au numéro fourni. Public (pas de JWT).

**Request body**
```json
{ "phone_number": "+33612345678" }
```

**Response 200**
```json
{ "expires_at": "2026-04-22T10:35:00Z" }
```

**Erreurs**
- `404 unknown_phone_number` : le numéro n'est pas autorisé en base
  (mappe vers `UnknownPhoneNumberException`).
- `429 rate_limited` : trop de demandes pour ce numéro (anti-spam SMS).
  Côté client, traité comme une erreur générique.

Le format E.164 est garanti par le client (`PhoneNumber.parse` valide
`^0[67]\d{8}$` puis convertit en `+33XXXXXXXXX`). Le backend peut
revalider mais peut aussi se contenter d'un check de format e164.

---

### `POST /auth/verify-otp`

Valide l'OTP et émet un JWT. Public.

**Request body**
```json
{
  "phone_number": "+33612345678",
  "code": "123456",
  "device_id": "9b2…uuid",
  "device_name": "iPhone de Papa"
}
```

`device_name` est optionnel (le modèle `Device.name` est `String?`).

**Response 200** — la forme du `Session` Dart (cf. `lib/core/domain/model/session.dart`) :

```json
{
  "jwt": "eyJ…",
  "device": { "id": "9b2…uuid", "name": "iPhone de Papa" },
  "profiles": [
    {
      "id": "papa",
      "name": "Papa",
      "age_category": "adulte",
      "is_main": true,
      "pin_hash": "$2b$12$…",
      "avatar_url": null
    },
    {
      "id": "ar",
      "name": "Ar",
      "age_category": "enfant",
      "is_main": false,
      "pin_hash": null,
      "avatar_url": null
    }
  ]
}
```

Le `pin_hash` (bcrypt, coût 12) est renvoyé pour permettre la
**vérification PIN locale et offline** côté client (cf.
`BcryptProfilePinService`). Le PIN brut ne quitte jamais le serveur après
hashing.

**Erreurs**
- `401 invalid_otp` (mappe `InvalidOtpException`).
- `410 otp_expired` (mappe `OtpExpiredException`).
- `404 unknown_phone_number` (idem `request-otp`).

Un nouvel appel à `request-otp` puis `verify-otp` doit invalider tout OTP
encore en attente pour le même numéro.

---

## Profils

Toutes les routes ci-dessous requièrent `Authorization` + `X-Device-Id`.
Le profil cible doit appartenir au compte du JWT, sinon `404`.

### `POST /profiles`

Mappe `ProfileManagementRepository.create`. Crée un profil **non principal**
(le profil principal est créé en DB par l'admin, pas via l'API).

**Request body**
```json
{
  "name": "Léa",
  "age_category": "enfant",
  "raw_pin": "1234"
}
```

`raw_pin` est optionnel ; quand fourni, c'est une string `^[0-9]{4}$`
(validation effectuée côté client par `CreateProfileUseCase`). Le serveur
hashe en bcrypt avant persistance.

**Response 200** — le profil créé, **avec son `id` stable généré par le
serveur** et `is_main: false`. Même structure que dans le tableau
`profiles[]` de `verify-otp`.

---

### `PATCH /profiles/{id}`

Mappe `updateMetadata`. Met à jour `name` et `age_category` ; ne touche
ni au `pin_hash`, ni à `is_main`, ni à `avatar_url`.

**Request body**
```json
{ "name": "Léa", "age_category": "ado" }
```

**Response 200** — le profil après update.

---

### `PUT /profiles/{id}/pin`

Mappe `setPin`. Définit ou remplace le PIN.

**Request body**
```json
{ "raw_pin": "9876" }
```

Le serveur valide `^[0-9]{4}$`, hashe en bcrypt, persiste, renvoie le
profil mis à jour.

**Response 200** — le profil avec son nouveau `pin_hash`.

---

### `DELETE /profiles/{id}/pin`

Mappe `clearPin`. Supprime le PIN d'un profil non principal.

**Response 200** — le profil avec `pin_hash: null`.

**Erreurs**
- `422 cannot_clear_main_profile_pin` : le profil cible a `is_main: true`
  (mappe `CannotClearMainProfilePinException`).

---

### `DELETE /profiles/{id}`

Mappe `delete`. Supprime un profil non principal.

**Response 204** (no content).

**Erreurs**
- `422 cannot_delete_main_profile` : le profil cible a `is_main: true`
  (mappe `CannotDeleteMainProfileException`).

---

## Catalogue

Auth requise sur tous les endpoints.

### `GET /movies?age_category={cat}`

Mappe `CatalogRepository.listMoviesFor(ageCategory)`. Renvoie **uniquement**
les films de la catégorie demandée — pas d'expansion hiérarchique à ce
niveau (l'expansion `lowerOrEqual` est utilisée seulement par la recherche).

**Query**
- `age_category` (requis) : valeur de l'enum `AgeCategory`.

**Response 200**
```json
{
  "movies": [
    {
      "id": "asterix-empire-du-milieu",
      "title": "Astérix & Obélix : L'Empire du Milieu",
      "original_title": "Astérix & Obélix : L'Empire du Milieu",
      "year": 2023,
      "duration_seconds": 6720,
      "synopsis": "…",
      "tagline": "Il y a très très longtemps…",
      "poster_url": "https://image.tmdb.org/t/p/original/vchpiQLvXa4uyZhqdEwttrsFOOC.jpg",
      "backdrop_url": "https://image.tmdb.org/t/p/original/pYHnIePp56sQhonIJJ9RRfBmAPU.jpg",
      "age_category": "enfant",
      "genres": ["Familial", "Comédie", "Aventure", "Fantastique"],
      "saga_id": "asterix",
      "saga_label": "Astérix",
      "director": ["Guillaume Canet"],
      "cast": [
        { "name": "Guillaume Canet", "role": "Astérix", "photo_url": null },
        { "name": "Gilles Lellouche", "role": "Obélix", "photo_url": null }
      ],
      "added_at": "2026-04-20T00:00:00Z"
    }
  ]
}
```

Champs nullables côté Domain : `original_title`, `year`, `tagline`,
`poster_url`, `backdrop_url`, `saga_id`, `saga_label`, plus `cast[].role`
et `cast[].photo_url`.

**Notes**
- Les URLs d'images peuvent être des URLs absolues du proxy kDrive ou
  être des paths relatifs servis par le backend (par ex. `/movies/{id}/poster`)
  — le client se contente de faire un `Image.network(url)`.
- Le tri n'est pas imposé par le contrat ; l'application service trie
  ensuite côté client (Récemment ajoutés, sagas, genres…).
- Pas d'endpoint séparé `GET /movies/{id}` : l'app récupère la liste pour
  la catégorie active du profil et résout les détails localement (cf.
  `home.page.dart:76`, `player.page.dart:155`).

---

### `GET /movies?search={q}&up_to_age_category={cat}`

Mappe `CatalogRepository.searchMovies(query, upToAgeCategory)`. Doit
retourner les films **dont la catégorie est ≤ `up_to_age_category`** dans
la hiérarchie `bebe < enfant < ado < jeuneAdulte < adulte`, et dont le
`title` OU le `original_title` contient `search` après normalisation
**case- et accent-insensible** (`shared/text_normalization.dart`).

Le client n'impose ni longueur minimale (responsabilité UI) ni tri
(le service applicatif trie alphabétiquement sur le titre).

**Response 200** — même schéma que `GET /movies?age_category=…`.

> Le contrat `searchMovies` est explicitement documenté côté Dart comme
> devant être 1:1 avec un endpoint backend unique
> (`catalog.repository.dart` lignes 30-34). Ne pas le découper.

---

## Téléchargement de fichier vidéo

### `GET /movies/{movie_id}/download`

Mappe `DownloadRepository.download(movieId)`. Le client est `dio` en mode
`ResponseType.stream` ; il s'attend à un comportement HTTP standard avec
support des **range requests**.

**Headers requête**
- `Authorization: Bearer …` (auth requise)
- `X-Device-Id: …`
- `Range: bytes=<start>-` (présent quand le client reprend un download
  partiel — cf. `in_memory.download.repository.dart:165-171`).

**Response**
- `200 OK` quand pas de `Range` : flux complet du MP4. Header
  `Content-Length` requis pour exposer la taille totale.
- `206 Partial Content` quand `Range` est fourni : flux partiel à partir
  de `start`. Header `Content-Range: bytes <start>-<end>/<total>` requis
  (le client parse le total depuis ce header — regex `/(\d+)\s*$`
  dans `_resolveTotalSize`).
- `404` si le `movie_id` est inconnu.
- `403` si le user n'a aucun profil dont la catégorie d'âge donne accès
  à ce film (vérification de permission **non négociable** : voir
  GLOBALVIEW §"Logique de permissions critiques"). Le client n'a pas de
  gestion fine de ce cas — un 403 sera remonté comme `DownloadStatus.failed`.

**Body** : binaire `video/mp4`, H.264 + AAC, web-optimized (moov atom au
début pour permettre la lecture progressive).

Pas d'endpoint complémentaire : `cancel` et `delete` du repository
agissent uniquement sur le filesystem local (le `.partial` et le `.mp4`).

---

## Progression de lecture (watch progress)

Auth requise. Le `profile_id` du path doit appartenir au user du JWT.
Les positions sont des **secondes entières** (`positionSeconds: int`).

### `GET /profiles/{profile_id}/progress/{movie_id}`

Mappe `WatchProgressRepository.findFor(profileId, movieId)`.

**Response 200**
```json
{
  "profile_id": "ar",
  "movie_id": "nemo",
  "position_seconds": 1845,
  "completed": false,
  "updated_at": "2026-04-22T10:30:00Z"
}
```

**Response 204** quand aucune progression n'existe pour la paire
`(profile_id, movie_id)`. Le repository renvoie `null` dans ce cas.

> Une variante 200 + `null` body est aussi acceptable mais 204 est plus
> idiomatique HTTP. Le client gère les deux trivialement.

---

### `PUT /profiles/{profile_id}/progress/{movie_id}`

Mappe `WatchProgressRepository.save(progress)`. Sémantique **upsert** :
remplace verbatim toute entrée existante pour la même paire
`(profile_id, movie_id)`. Le repository ne fusionne ni n'accumule.

**Request body**
```json
{
  "position_seconds": 1900,
  "completed": false,
  "updated_at": "2026-04-22T10:30:10Z"
}
```

`updated_at` est calculé côté client (`SaveWatchProgressUseCase` pose
`DateTime.now()`). Le serveur peut soit le respecter, soit le réécrire à
sa propre `now()` — au choix tant que la valeur est renvoyée à la lecture
suivante. Le client ne s'en sert pas pour résoudre des conflits.

**Response 200** — entrée stockée (mêmes champs que `GET`).

**Note multi-device** : le serveur écrase la ligne (clé primaire
`(profile_id, movie_id)`), comme prévu dans GLOBALVIEW §"Règle de reprise
multi-device". Pas de gestion de version vector côté client.

---

### `GET /profiles/{profile_id}/progress`

Mappe `WatchProgressRepository.listForProfile(profileId)`. Renvoie
toutes les entrées de progression du profil dans un ordre **non
spécifié** par le contrat (l'application client trie si nécessaire).

**Response 200**
```json
{
  "progress": [
    {
      "profile_id": "ar",
      "movie_id": "nemo",
      "position_seconds": 1845,
      "completed": false,
      "updated_at": "2026-04-22T10:30:00Z"
    }
  ]
}
```

Liste vide quand le profil n'a aucune progression (jamais d'erreur).

---

## Catalogue d'erreurs

Codes machine que le client peut éventuellement traiter spécifiquement.
Tout autre code est traité comme erreur générique.

| Code HTTP | `error.code` | Origine côté Dart |
|---|---|---|
| 401 | `invalid_otp` | `InvalidOtpException` |
| 410 | `otp_expired` | `OtpExpiredException` |
| 404 | `unknown_phone_number` | `UnknownPhoneNumberException` |
| 422 | `cannot_clear_main_profile_pin` | `CannotClearMainProfilePinException` |
| 422 | `cannot_delete_main_profile` | `CannotDeleteMainProfileException` |
| 401 | `invalid_token` | JWT manquant / invalide / expiré |
| 403 | `forbidden_age_category` | Tentative d'accès à un film hors permission |
| 404 | `not_found` | Profil ou film inexistant |

Le client n'a **pas** de gestion centralisée du `401 invalid_token` à ce
jour : un retour 401 sur une route authentifiée se traduira par une
erreur générique remontée à l'UI. Si le backend impose une expiration
courte du JWT, prévoir l'ajout d'un endpoint de refresh sera une
**feature** (hors scope de cette doc).

---

## Hors scope

Tout ce qui suit existe dans `GLOBALVIEW.md` mais **n'est pas consommé
par l'app actuelle** et donc pas requis par cette doc :

- `POST /auth/refresh` (l'app ne renouvelle jamais le JWT).
- `POST /auth/logout` (le `LogoutUseCase` ne fait que `clearSessionPreserveDevice`
  côté client, pas d'appel serveur).
- `GET /catalog` séparé de `GET /movies` (le client n'utilise qu'une seule
  liste filtrée par catégorie).
- `GET /movies/:id` détail isolé (le client résout depuis la liste).
- `GET /movies/:id/poster` (les `poster_url` sont absolues dans la réponse).
- Endpoints admin (`/admin/rescan`, `/admin/stats`).

Ces endpoints peuvent exister côté serveur sans casser le client, mais ne
sont pas un prérequis pour faire tourner l'app dans son état actuel.
