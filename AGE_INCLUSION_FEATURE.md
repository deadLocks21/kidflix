# Inclusion des tranches d'âge inférieures sur la home

Récap de la feature à implémenter côté backend.

## Idée

Permettre à un profil de voir, sur sa home, les contenus de sa propre
tranche d'âge **plus** ceux de tranches strictement inférieures qu'il a
explicitement choisies. La sélection est persistée sur le profil et
appliquée par le serveur dans le filtre `GET /catalog`.

## Backend

### Schéma

Une colonne sur la table `profiles` :

```sql
ALTER TABLE profiles
  ADD COLUMN included_lower_age_categories TEXT[] NOT NULL DEFAULT '{}';
```

Valeurs autorisées : sous-ensemble des `age_category` listées dans
`API.md § Conventions`, toutes **strictement inférieures** à la
`age_category` du profil dans l'ordre hiérarchique
`bebe < enfant < ado < jeune_adulte < adulte`. Pas de doublon.

### `PATCH /profiles/{id}` — extension

Le body accepte désormais un champ optionnel
`included_lower_age_categories: string[]`.

```json
{ "included_lower_age_categories": ["bebe", "enfant"] }
```

- **Absent du body** → valeur inchangée en DB.
- **Tableau (même vide)** → remplacement complet de la valeur en DB.
- **Validation** : tout élément doit être une `age_category` valide
  **et** strictement inférieure à la `age_category` courante du profil.
  Sinon `400 invalid_included_age_categories`, ligne inchangée.
- Combinable avec les autres champs : `name`, `avatar_id`,
  `age_category` continuent de fonctionner exactement comme aujourd'hui.
- La règle "au moins un champ requis" du `PATCH` existant englobe
  naturellement ce nouveau champ.

#### Règle d'accès

Mêmes règles que pour `name` / `avatar_id` (cf. `API.md` §
`PATCH /profiles/{id}`) :

| Profil actif (`X-Profile-Id`) | Profil ciblé (`:id`) | Comportement |
|---|---|---|
| `is_main = true` | n'importe lequel du même user | autorisé |
| `is_main = false` | == `X-Profile-Id` (soi-même) | autorisé en auto-édition |
| `is_main = false` | ≠ `X-Profile-Id` | `403 main_profile_required` |

### `GET /catalog` — changement de filtre

Le filtre **strict** actuel (`item.age_category == profile.age_category`)
est remplacé par :

```
item.age_category IN ({profile.age_category} ∪ profile.included_lower_age_categories)
```

Les autres filtres âge ne changent pas :

- `GET /catalog/search` reste inclusif sur toute la hiérarchie inférieure
  (`item.age_category ≤ profile.age_category`).
- `GET /series/{id}`, `GET /movies/{id}/download`,
  `GET /episodes/{id}/download` restent inclusifs sur la hiérarchie
  inférieure.

### Réponses Profile

Toutes les routes qui renvoient un objet profil (`POST /auth/verify-otp`,
`GET /profiles`, `POST /profiles`, `PATCH /profiles/{id}`, routes PIN)
gagnent le champ `included_lower_age_categories: string[]` (toujours
présent, jamais `null` — tableau vide par défaut).

```json
{
  "id": "kid-01",
  "name": "Léa",
  "age_category": "ado",
  "is_main": false,
  "pin_hash": null,
  "avatar_id": "profile-01",
  "included_lower_age_categories": ["bebe", "enfant"]
}
```

### Catalogue d'erreurs

| HTTP | Code | Quand |
|---|---|---|
| 400 | `invalid_included_age_categories` | Élément inconnu, doublon, ou élément ≥ `profile.age_category` |

## Compatibilité

- Colonne `NOT NULL DEFAULT '{}'` → tous les profils existants ont
  `included_lower_age_categories = []` après migration. Le filtre
  `GET /catalog` reste donc **identique** au comportement strict actuel
  tant qu'aucun client n'a renseigné le champ. Pas de breaking côté
  client en l'état.
- Client app actuel (sans connaissance du nouveau champ) : la clé
  supplémentaire dans les réponses est ignorée par les parseurs Dart
  existants. Déployable indépendamment de l'app.

## Hors scope

- Inclusion d'âges **supérieurs** (refusé par design).
- Endpoint dédié `PUT /profiles/{id}/age-inclusion` — on passe par
  `PATCH /profiles/{id}` standard.
- Migration de pré-cocher automatiquement des âges inférieurs sur les
  profils existants.

## Décisions produit à confirmer avant déploiement

1. **Auto-édition** : un profil non-principal peut-il modifier ses
   propres inclusions, ou seul le profil principal ? Doc ci-dessus =
   auto-édition autorisée (cohérent avec `name` / `avatar_id` / PIN).
   Si "main only", retirer la ligne auto-édition du tableau d'accès et
   renvoyer `403 main_profile_required` dans ce cas.
2. **Défaut à la création de profil** : `[]` (comportement actuel
   préservé, l'utilisateur opte-in via les settings) ou pré-cocher tous
   les âges strictement inférieurs ? Doc ci-dessus = `[]`.
