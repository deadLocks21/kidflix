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

## Lecture vidéo

Le bouton `"Lire"` de la modale de détails ouvre la `PlayerPage`
(`/player/:movieId`), qui orchestre :

1. **Download** — `InMemoryDownloadRepository` télécharge via `dio` depuis
   une URL unique en dur (Big Buck Bunny sur archive.org, ~62 MB,
   720p ~10 min, MP4 H.264) vers
   `${applicationDocumentsDirectory}/downloads/${movieId}.mp4.partial`.
   Dès que 2 Mo sont reçus (seuil `readyToPlay`), la lecture démarre sur
   le fichier partiel — le download continue en fond et le `.partial`
   est renommé en `.mp4` à la fin.
2. **Reprise** — si une `WatchProgress` existe pour la paire
   `(profile, movie)` avec `positionSeconds >= 10` et `completed == false`,
   un dialogue bloquant `"Reprendre la lecture ?"` propose `"Reprendre à
   Xh YY"` ou `"Recommencer"`.
3. **Sauvegarde** — la progression est sauvegardée toutes les 10s
   pendant la lecture, à la fermeture de la page, et au franchissement
   du seuil de complétion (> 90% regardé).
4. **Lecture** — `media_kit` joue le fichier local avec ses contrôles
   natifs (`MaterialVideoControls` sur mobile, `MaterialDesktopVideoControls`
   sur desktop), configurés via `MaterialVideoControlsTheme` :
   - **Top bar custom** : bouton Close + titre du film
   - **Bottom bar standard** : play/pause, position, fullscreen
     (+ volume sur desktop)
   - `speedUpOnLongPress` et `seekOnDoubleTap` désactivés (gestes
     "pro" qui surprendraient un enfant)
   - Auto-hide après 3s sans interaction, géré par media_kit
   Les raccourcis clavier (espace, flèches) sont câblés gratuitement
   par la lib. Le seek au-delà du buffered est toléré — mpv stalle
   brièvement le temps que le download rattrape.
5. **Mobile** — orientation landscape forcée, `SystemUiMode.immersiveSticky`,
   wakelock actif pendant la lecture.

Le `WatchProgressRepository` est un `InMemoryWatchProgressRepository`
(Map en RAM) — les progressions sont perdues au redémarrage de l'app.
Le contrat domain est identique à ce que sera l'implémentation HTTP
(`GET/POST /progress/:movieId`) : aucune modification de l'API client
attendue lors du branchement sur le backend.

**Hors scope** (changements ultérieurs) : kid lock natif
(Android `startLockTask` / iOS Accès Guidé), download en arrière-plan,
file d'attente multi-films, contrôles avancés (vitesse, sous-titres,
skip ±10s), alimentation réelle de la row `continueWatching` de la
home.

## Tests

```bash
flutter test
```
