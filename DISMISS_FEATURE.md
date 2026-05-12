# Retirer un film/épisode de "Continuer à regarder"

Récap de la feature à implémenter côté backend, puis côté app.

## Idée

Ajouter un soft-dismiss : on cache l'entrée du rail sans toucher à la
position, et on remet le titre dans le rail dès que l'utilisateur relance
la lecture.

## Backend

### Schéma

Une colonne sur la table `watch_progress` :

```sql
ALTER TABLE watch_progress
  ADD COLUMN dismissed BOOLEAN NOT NULL DEFAULT FALSE;
```

### Endpoints

Deux paires jumelles film/épisode, idempotentes :

| Route | Effet |
|---|---|
| `POST   /profiles/{p}/progress/movies/{m}/dismiss`   | `dismissed = TRUE` |
| `DELETE /profiles/{p}/progress/movies/{m}/dismiss`   | `dismissed = FALSE` |
| `POST   /profiles/{p}/progress/episodes/{e}/dismiss` | `dismissed = TRUE` |
| `DELETE /profiles/{p}/progress/episodes/{e}/dismiss` | `dismissed = FALSE` |

- Réponse : `204 No Content`.
- Si la row n'existe pas → `404 not_found` (pas de création implicite).
- Idempotent : rejouer un `POST` ou un `DELETE` est sans effet et
  renvoie `204`.
- Pas de body sur `POST` / `DELETE` ; body non vide → `400 invalid_request`.
- Mêmes règles d'auth que le reste du namespace (`403 forbidden_profile`
  si `X-Profile-Id` ≠ `profile_id`).

### Règle d'auto-reset

À chaque `PUT /profiles/{p}/progress/movies/{m}` ou `…/episodes/{e}`
réussi, le serveur force `dismissed = FALSE`. Pas de champ `dismissed`
dans le body du `PUT` (le body strict actuel le rejetterait avec `400`).

→ Si l'utilisateur relance la lecture après un dismiss, la prochaine
sauvegarde de position fait réapparaître le titre dans le rail
naturellement.

### Responses GET

Les trois GET existants gagnent le champ `dismissed: bool` (toujours
présent) dans chaque bare object :

```json
{
  "kind": "movie",
  "profile_id": "ar",
  "media_id": "nemo",
  "position_seconds": 1845,
  "completed": false,
  "dismissed": false,
  "updated_at": "2026-04-22T10:30:00Z"
}
```

Le serveur **ne filtre pas** les entries `dismissed: true` — le client
décide. Cohérent avec le choix de ne pas exposer
`/continue-watching` calculé.

## App (Flutter)

À faire dans une PR séparée, après le déploiement backend :

1. Ajouter `dismissed` à `RemoteWatchProgressDto` et au domaine
   `WatchProgress` (`MovieProgress` + `EpisodeProgress`).
2. Ajouter `dismiss(media)` / `unDismiss(media)` à
   `WatchProgressRepository` (Domain + Dio + InMemory).
3. Ajouter le filtre `!progress.dismissed` dans
   `ResolveContinueWatchingUseCase`.
4. Action UI : long-press sur la carte du rail → bottom-sheet avec
   « Retirer de Continuer à regarder » qui appelle
   `WatchProgressRepository.dismiss(...)`.

## Compatibilité

- Backend déployable avant l'app : le champ `dismissed` ajouté dans les
  responses est silencieusement ignoré par le parseur actuel.
- Pas de breaking change client. Pas de nouveau code d'erreur.

## Hors scope

- Suppression dure de l'entrée (perd la position).
- Bulk dismiss.
- Timestamp `dismissed_at` / analytics.
- Endpoint serveur `/continue-watching` calculé.
