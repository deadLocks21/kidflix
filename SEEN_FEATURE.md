# Déjà vu (Seen) — contrat client/serveur

Permet à un profil de marquer des films comme **déjà vus** ("déjà vu"),
hors de tout visionnage dans l'app. Deux usages côté client :

1. **Toggle unitaire** sur la modale de détail d'un film.
2. **Saisie en masse** via l'écran *Réglages → Films déjà vus* (grille du
   catalogue, sélection multiple, un seul enregistrement).

Effet produit : un film déjà vu (marqué ici **ou** complété en lecture,
cf. `WatchProgress.completed`) est exclu de la rangée « Jamais vus » de
l'accueil.

> **Périmètre MVP** : films uniquement (comme la rangée « Jamais vus »,
> cf. `add-series-viewing/design.md` D-5). Les séries pourront être
> ajoutées plus tard via un `kind: "series"` sur le même schéma.

## Modèle de données

Clé composite `(profile_id, media_kind, media_id)` — identique à
Favoris. `marked_at` est un état, pas une identité.

| Champ | Type | Notes |
|---|---|---|
| `kind` | `"movie"` | `"series"` réservé pour plus tard |
| `profile_id` | string | profil propriétaire de la marque |
| `media_id` | string | id du film |
| `marked_at` | ISO-8601 UTC | date de marquage |

## Endpoints

Toutes les routes requièrent `Authorization` + `X-Device-Id` +
`X-Profile-Id` (injectés par l'`AuthInterceptor`). Les mutations
répondent `204 No Content`.

### `GET /profiles/{profile_id}/seen`

Liste les marques « déjà vu » du profil.

```json
{
  "seen": [
    { "kind": "movie", "profile_id": "p1", "media_id": "m42",
      "marked_at": "2026-05-12T10:30:00Z" }
  ]
}
```

### `PUT /profiles/{profile_id}/seen/movies/{movie_id}`

Marque un film comme déjà vu. **Idempotent** : rejouer le `PUT` sur une
paire déjà marquée est un `204` no-op et ne rafraîchit pas `marked_at`.

### `DELETE /profiles/{profile_id}/seen/movies/{movie_id}`

Retire la marque. **Idempotent** : `DELETE` sur une paire inconnue est un
`204` no-op (pas de `404`, comme Favoris).

### `PUT /profiles/{profile_id}/seen` *(bulk)*

Marque plusieurs films en une requête (écran de saisie en masse).
Idempotent par id ; un tableau vide est un no-op.

```json
{ "movie_ids": ["m42", "m43", "m51"] }
```

Réponse `204`. Le serveur applique chaque id comme un `PUT` unitaire
(création si absent, no-op si présent). La suppression en masse n'est pas
exposée : le client retire les marques décochées via le `DELETE`
unitaire ci-dessus (rare dans un flux de saisie).

## Erreurs

Format d'erreur standard de l'API (cf. `API.md` § « Format d'erreur »).
Aucun mapping métier côté client : tout `4xx`/`5xx`/réseau remonte en
`DioException` générique et déclenche un snackbar de réessai.

## Implémentations client

- Port : `SeenRepository` (`lib/core/domain/services/seen.repository.dart`).
- HTTP : `DioSeenRepository` (`lib/infrastructure/seen/`).
- Dev / web / tests : `InMemorySeenRepository` (sélectionné quand l'URL
  de base est vide/démo) — rend toute la feature exerçable sans backend.
- État : `SeenController` (`seen.controller_provider.dart`), mutations
  optimistes avec rollback ; `markManySeen` appelle l'endpoint bulk.
