# kidflix

Application familiale Flutter pour la médiathèque kDrive.

## Lancer l'application

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos   # ou -d chrome, -d <deviceId>
```

## Architecture

Architecture hexagonale, layers avec dépendances unidirectionnelles :
`UI → Application → Domain ← Infrastructure`.

- `lib/core/domain/` : modèles, interfaces, exceptions (pur Dart)
- `lib/core/application/` : usecases, DTOs, services applicatifs
- `lib/infrastructure/` : implémentations + providers Riverpod
- `lib/ui/` : pages Flutter + router

Détails dans `/Users/timh/Projects/songbook-app/ARCHITECTURE.md` (mêmes conventions).

## Données de test (mode InMemory)

Le backend n'est pas encore développé. L'app utilise `InMemoryAuthRepository`
avec les numéros suivants :

| Téléphone       | Profils                                          |
| --------------- | ------------------------------------------------ |
| `0612345678`    | Papa (PIN `1234`), Ar (sans PIN), Ro (PIN `9999`) |
| `0787654321`    | Alice (PIN `0000`), Li (sans PIN)                 |

Code OTP accepté pour tous les numéros autorisés : **`123456`**.
Tout autre numéro renvoie "numéro inconnu". Tout autre code renvoie
"code invalide".

## Catalogue de films (in-memory MVP)

En attendant le backend (phase 2), le catalogue vit dans
`InMemoryCatalogRepository`. Il expose ~12 films stub répartis sur les 5
catégories d'âge (2 sagas Astérix et Harry Potter en `enfant`, au moins
un film par autre catégorie). Les posters et backdrops sont de vraies
URLs publiques TMDB (`https://image.tmdb.org/t/p/original/...`) — le
cache disque (`cached_network_image`) permet un fonctionnement offline
après le premier chargement.

La homepage empile 7 types de rows : `continueWatching`, `recentlyAdded`,
`favorites`, `saga`, `genre`, `neverWatched`, `downloaded`. Une row vide
est masquée. Quatre types (`continueWatching`, `favorites`,
`neverWatched`, `downloaded`) sont des **stubs temporaires** (sous-listes
arbitraires du catalogue filtré) matérialisés par des helpers privés de
`CatalogApplicationService` portant un `// TODO(MVP)`. Ils seront
remplacés par les vrais repositories (`WatchProgressRepository`,
`FavoritesRepository`, `DownloadsRepository`) quand les capabilities
correspondantes arriveront dans leurs propres changes.

Le filtre d'âge est **strict sur la homepage** (`profile.ageCategory ==
movie.ageCategory`). La permission hiérarchique (`bebe < enfant < ado <
jeuneAdulte < adulte`) est matérialisée par l'extension
`AgeCategoryHierarchy.lowerOrEqual` et utilisée par la recherche
ci-dessous.

## Recherche de films

Une barre de recherche est accessible via l'icône loupe dans l'AppBar de
la homepage. Elle s'ouvre inline (sans navigation vers une autre page),
bascule l'AppBar en champ de saisie, et remplace les rows par la liste
des résultats. La fermeture restaure la home à sa position de scroll
précédente (via `IndexedStack`).

Portée : un profil voit tous les films dont `ageCategory` est inférieure
ou égale à la sienne (un profil `ado` accède aux films `bebe` + `enfant`
+ `ado`, un profil `bebe` ne voit que `bebe`).

Matching : insensible à la casse et aux accents, substring sur `title` et
`originalTitle`. Normalisation dans `lib/shared/text_normalization.dart`.
Seuil minimum de 2 caractères, debounce 250 ms, tri alphabétique.

## Tests

```bash
flutter test
```
