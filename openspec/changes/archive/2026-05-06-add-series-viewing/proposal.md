## Why

L'app ne sait afficher et lire que des **films**. Le catalog familial
contient désormais aussi des **séries** (Pingu, et toute série découpée
en saisons/épisodes par le scanner tinyMediaManager TV). Le backend
expose déjà toute l'infrastructure nécessaire — endpoint mixte
`/catalog`, endpoint détail `/series/{id}`, download d'épisode,
progression épisode polymorphe — depuis sa propre change `add-series-viewing`
côté `kidflix-api` (cf. `API.md` § Catalogue, § Détail d'une série,
§ Progression de lecture). L'app cliente, elle, n'a rien bougé : elle
appelle encore `GET /movies` (qui n'existe plus) et ne sait que parler
de films.

Cette change est la **contrepartie front** de cette évolution serveur.
Elle est requise pour que l'app HTTP redevienne fonctionnelle (les
renames `/movies → /catalog` et `/progress/{m} → /progress/movies/{m}`
sont breaking côté serveur), et elle ouvre l'app au visionnage des
séries de bout en bout : modale détail série, liste saisons/épisodes,
téléchargement et lecture d'épisode, reprise de lecture, et calcul
client-side du "prochain épisode" pour le row Continue Watching.

## What Changes

### Domaine

- **NOUVEAU** `lib/core/domain/model/media.dart` regroupe une hiérarchie
  scellée `CatalogItem` (= `Movie | Series`) et une seconde hiérarchie
  scellée `PlayableMedia` (= `Movie | Episode`). `Movie` cohabite dans
  les deux : il étend `CatalogItem` et implémente `PlayableMedia`.
  `Series` étend `CatalogItem` seul ; `Episode` étend `PlayableMedia`
  seul. La classe `CastMember` reste dans le même fichier.
- **NOUVEAU** `Series` : entité catalog non-jouable, porte les
  `seasonsCount` / `episodesCount` calculés serveur-side ; expose
  `seasons: List<Season>` quand chargée via `SeriesRepository.findById`
  (vide en provenance de `/catalog`).
- **NOUVEAU** `Season` : sous-entité de `Series` (non sealed),
  `seasonNumber`, `name?`, `posterUrl?`, `synopsis?`, `episodes`.
- **NOUVEAU** `Episode` : `id`, `seriesId`, `seasonNumber`,
  `episodeNumber`, `title`, `originalTitle?`, `synopsis?`, `duration`,
  `thumbUrl?`, `airedAt? (DateTime)`, `addedAt`. Implémente
  `PlayableMedia`.
- **MODIFIÉ** `lib/core/domain/model/movie.dart` est **retiré** ; son
  contenu (`Movie`, `CastMember`) migre dans `media.dart` — contrainte
  Dart sur les sealed (sous-types dans la même librairie).
- **MODIFIÉ** `WatchProgress` devient une sealed avec
  `MovieProgress(movieId)` et `EpisodeProgress(episodeId)`. Le champ
  `profileId`, `positionSeconds`, `completed`, `updatedAt` migrent dans
  la classe sealed parente.
- **MODIFIÉ** `CatalogRow.movies: List<Movie>` →
  `CatalogRow.items: List<CatalogItem>`. Le row peut désormais mélanger
  films et séries sur la même ligne (cas typique : Récemment ajoutés).

### Repositories (interfaces Domain)

- **MODIFIÉ** `CatalogRepository` :
  - `Future<List<Movie>> listMoviesFor()` →
    `Future<List<CatalogItem>> listCatalog()`.
  - `Future<List<Movie>> searchMovies({required String query})` →
    `Future<List<CatalogItem>> searchCatalog({required String query})`.
- **NOUVEAU** `SeriesRepository.findById(String seriesId)` : renvoie
  une `Series` complète (avec ses `seasons` et leurs `episodes`).
- **MODIFIÉ** `DownloadRepository` :
  - Renomme `downloadMovie(movieId)` (anciennement `download`) →
    nouvelle méthode jumelle `downloadEpisode(episodeId)`.
  - `findByMovieId` / `cancel` / `delete` deviennent typés par kind :
    `findFor(media)`, `cancel(media)`, `delete(media)` prenant un
    `PlayableMedia` (sealed).
- **MODIFIÉ** `WatchProgressRepository` :
  - `findFor({profileId, movieId})` → deux méthodes typées
    `findForMovie({profileId, movieId})` et
    `findForEpisode({profileId, episodeId})`, retournant respectivement
    `MovieProgress?` et `EpisodeProgress?`.
  - `save(WatchProgress)` accepte la sealed, polymorphe.
  - `listForProfile(profileId)` : `Future<List<WatchProgress>>` mixte.

### Wire DTOs

- **NOUVEAU** `lib/core/application/dtos/remote_catalog_item.dto.dart` :
  fonction de dispatch `RemoteCatalogItemDto.fromJson` qui lit le
  discriminator `kind` et délègue à `RemoteMovieDto.fromJson` ou
  `RemoteSeriesCatalogDto.fromJson`.
- **NOUVEAU** `RemoteSeriesCatalogDto` : forme catalog d'une série
  (sans saisons/épisodes, avec `seasons_count` / `episodes_count`).
- **NOUVEAU** `RemoteSeriesDetailDto`, `RemoteSeasonDto`,
  `RemoteEpisodeDto` : forme détail d'une série retournée par
  `GET /series/{id}`.
- **NOUVEAU** `lib/core/application/dtos/remote_watch_progress.dto.dart` :
  parse `kind` et produit `MovieProgress` ou `EpisodeProgress`.
- **MODIFIÉ** `RemoteMovieDto.fromJson` accepte (et ignore en MVP) le
  champ `kind: "movie"` au top-level pour la compatibilité avec le
  payload `/catalog` qui le porte sur tous les items.

### Implémentations HTTP (Dio)

- **MODIFIÉ** `DioCatalogRepository` :
  - `listCatalog()` : `GET /catalog`, parse `items[]` via
    `RemoteCatalogItemDto`.
  - `searchCatalog({query})` : `GET /catalog/search?q=...`, idem.
- **NOUVEAU** `DioSeriesRepository` :
  - `findById(seriesId)` : `GET /series/{id}`, parse
    `RemoteSeriesDetailDto`.
- **MODIFIÉ** `DioDownloadRepository` :
  - Existant `downloadMovie(movieId)` : `GET /movies/{id}/download`
    (inchangé sauf renommage interne).
  - **NOUVEAU** `downloadEpisode(episodeId)` :
    `GET /episodes/{id}/download` (mêmes garanties Range/HEAD).
- **MODIFIÉ** `DioWatchProgressRepository` :
  - `findForMovie` : `GET /profiles/{p}/progress/movies/{m}`.
  - `findForEpisode` : `GET /profiles/{p}/progress/episodes/{e}`.
  - `save(MovieProgress)` : `PUT /profiles/{p}/progress/movies/{m}`.
  - `save(EpisodeProgress)` : `PUT /profiles/{p}/progress/episodes/{e}`.
  - `listForProfile` : `GET /profiles/{p}/progress` (parse `kind`).

### Implémentations in-memory

- **NOUVEAU** `InMemorySeriesRepository` avec un seed Pingu (ou
  équivalent) : ≥ 1 série, ≥ 2 saisons (dont Specials saison 0),
  ≥ 5 épisodes par saison. Au moins un épisode de la série a une
  progression seedée pour exercer le row Continue Watching.
- **MODIFIÉ** `InMemoryCatalogRepository` :
  - Liste mixte films + séries (les séries seedées proviennent du seed
    de `InMemorySeriesRepository`, projetées sans saisons/épisodes).
- **MODIFIÉ** `InMemoryDownloadRepository` :
  - `downloadEpisode(episodeId)` : même mécanique fake que les films.
- **MODIFIÉ** `InMemoryWatchProgressRepository` :
  - Map clé `(profileId, MediaKind, mediaId)`.

### Application services / usecases

- **NOUVEAU** `ResolveContinueWatchingUseCase` : compose les progressions
  d'un profil (movie + episode) en items affichables. Pour les épisodes,
  résout la série parente via `SeriesRepository.findById` afin de
  calculer le "next episode" si `progress.completed`. Pas de cache pour
  l'instant (cf. design.md D-3).
- **NOUVEAU** `StartEpisodePlaybackUseCase` (jumeau de
  `StartMoviePlaybackUseCase` existant) : prend un `Episode`, lance le
  download via `DownloadRepository.downloadEpisode`, ouvre le player.
- **MODIFIÉ** `CatalogApplicationService.buildHomeRowsFor(profile)` :
  - Le row `recentlyAdded` mélange films et séries (tri par `addedAt`
    desc commun).
  - Les rows `saga` et `genre` n'incluent **que les films** pour le
    moment (les séries ont rarement un saga, et le genre est porté
    aussi par les séries — cf. design.md D-5).
  - Le row `continueWatching` est désormais alimenté par
    `ResolveContinueWatchingUseCase` (remplace le stub actuel).
  - Les rows `favorites`, `neverWatched`, `downloaded` continuent à
    n'exposer que des films au MVP (out-of-scope d'étendre aux séries
    dans cette change).
- **MODIFIÉ** `SearchApplicationService.searchFor({query, profile})` :
  retourne désormais `List<CatalogItem>` mixte. Le tri reste alpha sur
  `title`.

### UI

- **MODIFIÉ** carte de catalog (`MovieCard` → `CatalogItemCard`) : un
  switch sur le sealed `CatalogItem` rend la même esthétique poster +
  titre + caption. Pour `Series`, la caption affiche
  `"{year} · {seasonsCount} saison(s)"` à la place de
  `"{year} · {humanizedDuration}"`.
- **NOUVEAU** modale série (réutilise la modale film existante via un
  switch interne) : metadata identiques (backdrop, titre, synopsis,
  genres, casting), suivies d'une section "Saisons" empilée. Chaque
  saison est un `ExpansionTile` contenant la liste de ses épisodes.
  La saison de la progression la plus récente du profil est dépliée
  par défaut ; les autres collapsées. Specials (saison 0) est rendue
  en dernier.
- **NOUVEAU** carte épisode dans la liste : numéro `S{n}E{m}` ou `E{m}`,
  titre, durée humanisée, thumb_url, et — si une `EpisodeProgress`
  existe pour ce profil — un overlay barre de progression + ✓ si
  `completed`.
- **NOUVEAU** bouton "Lire" intelligent en haut de modale série : le
  label est calculé via `ResolveContinueWatchingUseCase` (ou un
  helper dédié) pour le profil actif :
  - aucune progression → `"Lire S{firstSeason}E{firstEpisode}"`
  - progression en cours → `"Reprendre S{n}E{m}"`
  - dernier épisode complété → `"Lire S{nextN}E{nextM}"`
  - série entièrement complétée → `"Revoir S1E1"`.
- **NOUVEAU** tap sur un épisode dans la liste → lance directement
  `StartEpisodePlaybackUseCase` (pas de modale épisode-spécifique).
- **MODIFIÉ** `PlayerPage` accepte désormais un `PlayableMedia` (sealed)
  au lieu d'un `Movie`. Le switch interne route vers le bon endpoint
  download et la bonne forme de `WatchProgress`.

## Capabilities

### New Capabilities

- `series-viewing` : couvre la modélisation Domain `Series / Season /
  Episode`, l'interface `SeriesRepository`, ses deux implémentations
  (in-memory + Dio), la modale détail série + liste épisodes, le
  player épisode, la `EpisodeProgress`, le calcul du "prochain épisode"
  pour Continue Watching, et le `ResolveContinueWatchingUseCase`.

### Modified Capabilities

- `catalog` : le repo bascule de `Movie` à `CatalogItem` (sealed
  `Movie | Series`). Les méthodes sont renommées (`listMoviesFor` →
  `listCatalog`, `searchMovies` → `searchCatalog`). `CatalogRow`
  porte des `items: List<CatalogItem>` mixtes. Les wire DTOs gagnent
  un dispatch sur `kind`. Les routes HTTP basculent de `/movies` et
  `/movies/search` vers `/catalog` et `/catalog/search`.
- `downloads` : ajoute `DownloadRepository.downloadEpisode(episodeId)`
  jumelle de l'existante (renommée) `downloadMovie`. Les méthodes de
  lookup (`findFor`, `cancel`, `delete`) deviennent polymorphes sur
  `PlayableMedia`.
- `video-playback` : `WatchProgress` devient une sealed (`MovieProgress
  | EpisodeProgress`). Le repo expose des méthodes typées
  (`findForMovie`, `findForEpisode`) ; `save` accepte la sealed ;
  `listForProfile` retourne du mixte. Le `PlayerPage` accepte un
  `PlayableMedia`.
- `search` : retourne `List<CatalogItem>` au lieu de `List<Movie>`. La
  route HTTP bascule de `/movies/search` à `/catalog/search` et le
  parsing utilise le dispatch `kind`.

## Impact

- **Code touché (Domain)** :
  - `lib/core/domain/model/media.dart` — NOUVEAU, regroupe sealed
    `CatalogItem`, sealed `PlayableMedia`, `Movie`, `Series`, `Season`,
    `Episode`, `CastMember`.
  - `lib/core/domain/model/movie.dart` — RETIRÉ (contenu migré).
  - `lib/core/domain/model/catalog_row.dart` — `movies` → `items :
    List<CatalogItem>`.
  - `lib/core/domain/model/watch_progress.dart` — refactor sealed.
  - `lib/core/domain/services/catalog.repository.dart` — rename des
    méthodes + retour `CatalogItem`.
  - `lib/core/domain/services/series.repository.dart` — NOUVEAU.
  - `lib/core/domain/services/download.repository.dart` — méthode
    `downloadEpisode`, polymorphisme des lookups.
  - `lib/core/domain/services/watch_progress.repository.dart` —
    méthodes typées + polymorphisme.
- **Code touché (Application)** :
  - `lib/core/application/dtos/remote_movie.dto.dart` — accepte le
    champ `kind`.
  - `lib/core/application/dtos/remote_series.dto.dart` — NOUVEAU
    (catalog form + detail form + season/episode DTOs).
  - `lib/core/application/dtos/remote_catalog_item.dto.dart` —
    NOUVEAU dispatch.
  - `lib/core/application/dtos/remote_watch_progress.dto.dart` —
    NOUVEAU.
  - `lib/core/application/services/catalog_application.service.dart`
    — adapter pour mixed items.
  - `lib/core/application/services/search_application.service.dart`
    — retour `List<CatalogItem>`.
  - `lib/core/application/usecases/resolve_continue_watching.usecase.dart`
    — NOUVEAU.
  - `lib/core/application/usecases/start_episode_playback.usecase.dart`
    — NOUVEAU.
  - `lib/core/application/usecases/start_movie_playback.usecase.dart`
    — adapter au nouveau contrat `DownloadRepository`.
  - `lib/core/application/usecases/save_watch_progress.usecase.dart`
    — adapter au sealed.
- **Code touché (Infrastructure)** :
  - `lib/infrastructure/catalog/dio.catalog.repository.dart` — routes
    `/catalog`.
  - `lib/infrastructure/catalog/in_memory.catalog.repository.dart` —
    seed mixte.
  - `lib/infrastructure/series/dio.series.repository.dart` — NOUVEAU.
  - `lib/infrastructure/series/in_memory.series.repository.dart` —
    NOUVEAU (seed Pingu).
  - `lib/infrastructure/downloads/dio.download.repository.dart` —
    méthode épisode.
  - `lib/infrastructure/downloads/in_memory.download.repository.dart`
    — méthode épisode (fake mécanique).
  - `lib/infrastructure/watch_progress/dio.watch_progress.repository.dart`
    — routes typées.
  - `lib/infrastructure/watch_progress/in_memory.watch_progress.repository.dart`
    — clé composite.
  - `lib/infrastructure/providers/series.repository_provider.dart` —
    NOUVEAU (sélection in-memory / Dio via `API_BASE_URL`).
- **Code touché (UI)** :
  - `lib/ui/catalog/movie_card.dart` → renommé en
    `lib/ui/catalog/catalog_item_card.dart` (switch interne).
  - `lib/ui/catalog/movie_detail_modal.dart` → renommé en
    `lib/ui/catalog/catalog_item_detail_modal.dart`, switch interne.
  - `lib/ui/catalog/series/season_section.dart` — NOUVEAU.
  - `lib/ui/catalog/series/episode_card.dart` — NOUVEAU.
  - `lib/ui/catalog/series/play_label.dart` — NOUVEAU helper "label
    dynamique".
  - `lib/ui/player/player_page.dart` — accepte `PlayableMedia`.
- **Tests** : large refacto suivant les renames + nouveaux tests pour
  `Series`, `Episode`, `EpisodeProgress`, `SeriesRepository` (in-memory
  et HTTP), `DioCatalogRepository` sur `/catalog`,
  `ResolveContinueWatchingUseCase` (cas movie / episode in-progress /
  episode completed → next / fin de série).
- **API.md** : aucune modification nécessaire — le doc reflète déjà
  l'état serveur cible.
- **Dependencies** : aucune. Les sealed Dart 3 sont déjà disponibles.
- **Breaking changes** :
  - HTTP : impossible de tourner contre une ancienne API qui n'a pas
    `add-series-viewing` côté serveur. Le déploiement client doit
    suivre celui du serveur.
  - In-memory : le contrat de `CatalogRow.movies` change de nom (et
    de type). Tout test ou consommateur qui accédait directement
    `row.movies` doit basculer sur `row.items`.
  - Domaine : `WatchProgress` devient sealed ; les sites qui
    construisaient un `WatchProgress` directement doivent choisir
    `MovieProgress` ou `EpisodeProgress`.
- **Build/run** :
  - `flutter run` (in-memory) : le seed contient désormais Pingu (ou
    équivalent) en plus des films. La homepage affiche film + série
    mélangés.
  - `flutter run --dart-define=API_BASE_URL=http://...` (HTTP) :
    requiert un backend `add-series-viewing`-ready.
- **Hors scope (différé)** :
  - Cache de `/series/{id}` (mémoire ou disque). Chaque construction
    de homepage qui contient N séries dans Continue Watching paye
    N appels à `findById` en parallèle. À reconsidérer dès qu'observable.
  - Étendre les rows `favorites`, `neverWatched`, `downloaded` aux
    séries.
  - Étendre les rows `saga` et `genre` aux séries.
  - "Auto-play next episode" depuis le player à la fin d'un épisode.
  - Mode offline série (catalogue + métadonnées de saison + épisodes
    déjà téléchargés). Suivra la même refonte qu'`add-offline-downloads`
    pour les films.
  - Endpoint `GET /series` ou tri/pagination dédiés ; aujourd'hui les
    séries arrivent via `/catalog`.
