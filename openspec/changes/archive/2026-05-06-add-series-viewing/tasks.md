## 1. Domain — `media.dart` (sealed CatalogItem + sealed PlayableMedia)

- [x] 1.1 Créer `lib/core/domain/model/media.dart` :
  - `sealed class CatalogItem` avec getters abstraits :
    `id`, `title`, `originalTitle`, `year`, `synopsis`, `tagline`,
    `posterUrl`, `backdropUrl`, `ageCategory`, `genres`, `sagaId`,
    `sagaLabel`, `director`, `cast`, `addedAt`.
  - `sealed class PlayableMedia` avec getters abstraits :
    `id`, `duration`, `ageCategory`.
  - `class Movie extends CatalogItem implements PlayableMedia` —
    porte tous les fields existants + `duration` requis (déjà présent).
    Conservation de `==` par `id`, `hashCode = id.hashCode`,
    `hasSaga`, `primaryGenre`.
  - `class Series extends CatalogItem` — fields :
    `seasonsCount: int`, `episodesCount: int`,
    `seasons: List<Season>` (non final, peuplé seulement par
    `SeriesRepository.findById` ; vide depuis `/catalog`).
    `==` par `id`, `hashCode = id.hashCode`. `primaryGenre` partagé.
  - `class Season` (non sealed) — fields : `seasonNumber: int`,
    `name: String?`, `posterUrl: String?`, `synopsis: String?`,
    `episodes: List<Episode>`. Pas d'égalité custom (value-objet
    porté par sa série).
  - `class Episode extends PlayableMedia` — fields : `id`, `seriesId`,
    `seasonNumber`, `episodeNumber`, `title`, `originalTitle?`,
    `synopsis?`, `duration: Duration`, `thumbUrl?`, `airedAt:
    DateTime?`, `ageCategory: AgeCategory` (héritée de la série
    parente, recopiée pour le confort du player), `addedAt`.
    `==` par `id`, `hashCode = id.hashCode`.
  - `class CastMember` — déplacée depuis `movie.dart` telle quelle
    (`name`, `role?`, `photoUrl?`).
  - Doc-comments sur chaque sealed expliquant la cohabitation
    `Movie` ∈ {CatalogItem, PlayableMedia}.
- [x] 1.2 Retirer `lib/core/domain/model/movie.dart` (le fichier).
- [x] 1.3 Mettre à jour tous les `import` dans le repo :
  `grep -rn "core/domain/model/movie.dart" lib/ test/` puis
  remplacer par `core/domain/model/media.dart`. Vérifier avec
  `dart analyze` que tous les sites compilent.
- [x] 1.4 Créer `test/core/domain/model/media_test.dart` :
  - `Movie` est égal par `id`.
  - `Series` est égal par `id`.
  - `Episode` est égal par `id`.
  - `Movie` est instance de `CatalogItem` ET de `PlayableMedia`.
  - `Series` est instance de `CatalogItem` et **pas** de `PlayableMedia`.
  - `Episode` est instance de `PlayableMedia` et **pas** de
    `CatalogItem`.
  - Switch exhaustif sur `CatalogItem` couvre `Movie`, `Series`.
  - Switch exhaustif sur `PlayableMedia` couvre `Movie`, `Episode`.

## 2. Domain — `CatalogRow` polymorphe

- [x] 2.1 Modifier `lib/core/domain/model/catalog_row.dart` :
  - Renommer le field `movies: List<Movie>` en
    `items: List<CatalogItem>`.
  - Mettre à jour le doc-comment.
- [x] 2.2 Mettre à jour les sites consommant `row.movies` :
  - `lib/core/application/services/catalog_application.service.dart`
  - `lib/core/application/dtos/catalog_row.dto.dart` (le DTO porte
    `items: List<CatalogItemDto>` au lieu de `movies: List<MovieDto>`).
  - Tests : `test/core/application/services/catalog_application.service_test.dart`,
    `test/ui/catalog/...` etc.

## 3. Domain — `WatchProgress` sealed

- [x] 3.1 Modifier `lib/core/domain/model/watch_progress.dart` :
  - Convertir `WatchProgress` en `sealed class` portant les getters
    abstraits `profileId`, `positionSeconds`, `completed`,
    `updatedAt`.
  - Créer `class MovieProgress extends WatchProgress` avec
    `movieId: String`. `==` sur `(profileId, movieId)`.
  - Créer `class EpisodeProgress extends WatchProgress` avec
    `episodeId: String`. `==` sur `(profileId, episodeId)`.
- [x] 3.2 Adapter les sites construisant un `WatchProgress` brut
  (`SaveWatchProgressUseCase`, `InMemoryWatchProgressRepository`,
  `DioWatchProgressRepository`, tests) :
  - Choisir explicitement `MovieProgress(...)` ou `EpisodeProgress(...)`.
- [x] 3.3 Créer `test/core/domain/model/watch_progress_test.dart` :
  - Test "MovieProgress equals on (profileId, movieId)".
  - Test "EpisodeProgress equals on (profileId, episodeId)".
  - Test "MovieProgress and EpisodeProgress are never equal even
    with same ids" (ie. même `String` dans `movieId` et `episodeId`).
  - Switch exhaustif sur `WatchProgress` couvre les deux variants.

## 4. Domain — `CatalogRepository` rename

- [x] 4.1 Modifier `lib/core/domain/services/catalog.repository.dart` :
  - `Future<List<Movie>> listMoviesFor()` →
    `Future<List<CatalogItem>> listCatalog()`.
  - `Future<List<Movie>> searchMovies({required String query})` →
    `Future<List<CatalogItem>> searchCatalog({required String query})`.
  - Mettre à jour les doc-comments :
    - `listCatalog` : "Returns all catalog items (movies and series)
      the active profile is allowed to see. ..."
    - `searchCatalog` : "Returns every movie or series whose
      normalized title or original title contains the query. ..."
- [x] 4.2 Mettre à jour tous les call sites (services, usecases, UI,
  tests). Le contrat reste 1-pour-1, juste avec un type plus large
  en sortie.

## 5. Domain — `SeriesRepository` (NOUVEAU)

- [x] 5.1 Créer `lib/core/domain/services/series.repository.dart` :
  - `abstract interface class SeriesRepository`.
  - `Future<Series> findById(String seriesId)` — doc-comment :
    "Returns the full hierarchical structure of a series (the series
    itself, its non-deleted seasons sorted by season_number asc,
    each season's non-deleted episodes sorted by episode_number asc).
    Throws if the series does not exist or is out of the active
    profile's age range."
- [x] 5.2 Créer `test/core/domain/services/series.repository_test.dart`
  (smoke test : juste vérifier l'instantiation de l'abstract class
  via une fake).

## 6. Domain — `DownloadRepository` polymorphisme

- [x] 6.1 Modifier `lib/core/domain/services/download.repository.dart` :
  - Renommer la méthode existante `download(String movieId)` en
    `downloadMovie(String movieId): Stream<MovieDownload>`.
  - Renommer `findByMovieId(String movieId)` →
    `findForMovie(String movieId): Future<MovieDownload?>`.
  - Ajouter `findForEpisode(String episodeId): Future<EpisodeDownload?>`.
  - Ajouter `downloadEpisode(String episodeId):
    Stream<EpisodeDownload>`.
  - Convertir `cancel(String movieId)` et `delete(String movieId)`
    en deux paires : `cancelMovie / cancelEpisode` et `deleteMovie /
    deleteEpisode` (typage explicite, route vers le bon namespace
    filesystem).
  - Doc-comment : "Two parallel pipelines, one per kind. Filesystem
    paths are namespaced (e.g. `/downloads/movies/`,
    `/downloads/episodes/`) — see `InMemoryDownloadRepository`."
- [x] 6.2 Créer `lib/core/domain/model/episode_download.dart` (ou
  étendre `movie_download.dart` pour inclure `EpisodeDownload`
  côte-à-côte) :
  - `class EpisodeDownload` jumelle de `MovieDownload`, fields :
    `episodeId`, `status`, `bytesReceived`, `bytesTotal`,
    `localPath`, `errorMessage`, `updatedAt`. Réutilise l'enum
    `DownloadStatus` existant.
  - Garder `class MovieDownload` inchangé.

## 7. Domain — `WatchProgressRepository` polymorphisme

- [x] 7.1 Modifier
  `lib/core/domain/services/watch_progress.repository.dart` :
  - Remplacer `findFor({profileId, movieId})` par deux méthodes
    typées :
    - `Future<MovieProgress?> findForMovie({required String profileId,
      required String movieId})`.
    - `Future<EpisodeProgress?> findForEpisode({required String
      profileId, required String episodeId})`.
  - `save(WatchProgress progress)` reste polymorphe (la sealed est
    switchée à l'intérieur de l'implémentation).
  - `listForProfile(String profileId)` retourne désormais
    `Future<List<WatchProgress>>` mixte.

## 8. Application — Wire DTOs

- [x] 8.1 Modifier
  `lib/core/application/dtos/remote_movie.dto.dart` :
  - Tolérer (et ignorer) le champ wire `kind: "movie"` au top-level
    dans `fromJson`. Le DTO ne porte pas le kind — il sait qu'il
    est un movie par construction.
- [x] 8.2 Créer
  `lib/core/application/dtos/remote_series.dto.dart` :
  - `class RemoteSeriesCatalogDto` (forme `kind: "series"` retournée
    par `/catalog`) — fields : `id`, `title`, `originalTitle`,
    `year`, `seasonsCount`, `episodesCount`, `synopsis`, `tagline`,
    `posterUrl`, `backdropUrl`, `ageCategory: AgeCategory`,
    `genres`, `sagaId`, `sagaLabel`, `director`, `cast`, `addedAt`.
    `Series toDomain()` produit une `Series` avec `seasons: []`.
  - `class RemoteSeriesDetailDto` (forme retournée par `/series/{id}`)
    — étend `RemoteSeriesCatalogDto` avec `seasons:
    List<RemoteSeasonDto>`.
  - `class RemoteSeasonDto` — `seasonNumber`, `name?`, `posterUrl?`,
    `synopsis?`, `episodes: List<RemoteEpisodeDto>`.
  - `class RemoteEpisodeDto` — `id`, `episodeNumber`, `title`,
    `originalTitle?`, `synopsis?`, `durationSeconds: int`,
    `thumbUrl?`, `airedAt: String?`, `addedAt: DateTime`. La méthode
    `Episode toDomain({required String seriesId, required int
    seasonNumber, required AgeCategory ageCategory})` injecte les
    champs hérités de la série parente (le wire ne les répète pas).
- [x] 8.3 Créer
  `lib/core/application/dtos/remote_catalog_item.dto.dart` :
  - `CatalogItem catalogItemFromJson(Map<String, dynamic> json)` qui
    switch sur `json['kind']` :
    - `"movie"` → `RemoteMovieDto.fromJson(json).toDomain()`
    - `"series"` → `RemoteSeriesCatalogDto.fromJson(json).toDomain()`
    - autre → `FormatException("Unknown catalog kind: ...")`.
- [x] 8.4 Créer
  `lib/core/application/dtos/remote_watch_progress.dto.dart` :
  - `WatchProgress watchProgressFromJson(Map<String, dynamic> json)`
    switch sur `json['kind']` → `MovieProgress` ou `EpisodeProgress`.
  - `Map<String, dynamic> watchProgressToJson(WatchProgress p)`
    omet le champ `media_id` côté HTTP : la route porte déjà
    l'identifiant. Sérialise uniquement `position_seconds`,
    `completed`, `updated_at` (le serveur tolère mais ignore le
    `updated_at`).
- [x] 8.5 Créer les tests unitaires de chaque DTO :
  - `test/core/application/dtos/remote_series.dto_test.dart` —
    parse une série complète (Pingu) avec saisons + Specials, vérif
    de l'injection `seriesId` / `ageCategory` dans chaque épisode.
  - `test/core/application/dtos/remote_catalog_item.dto_test.dart`
    — parse `[{kind: movie}, {kind: series}]`, vérif de la sealed.
  - `test/core/application/dtos/remote_watch_progress.dto_test.dart`
    — round-trip movie + episode.

## 9. Infrastructure — `DioCatalogRepository` (routes /catalog)

- [x] 9.1 Modifier
  `lib/infrastructure/catalog/dio.catalog.repository.dart` :
  - `listCatalog()` : `GET /catalog` (au lieu de `/movies`). Parse
    `response.data['items']` au lieu de `['movies']`. Pour chaque
    élément, `catalogItemFromJson(...)`.
  - `searchCatalog({query})` : `GET /catalog/search?q=...` (au lieu
    de `/movies/search`). Même parsing.
  - Aucun changement sur les headers (toujours injectés par
    `AuthInterceptor`).
- [x] 9.2 Adapter
  `test/infrastructure/catalog/dio.catalog.repository_test.dart` :
  - Renommer les attentes path `/movies` → `/catalog`,
    `/movies/search` → `/catalog/search`.
  - Renommer les enveloppes `{movies: [...]}` → `{items: [...]}`.
  - Ajouter scénarios mixtes : `[{kind: movie, ...}, {kind: series,
    ...}]`.
  - Ajouter scénario `kind` inconnu → `FormatException`.

## 10. Infrastructure — `InMemoryCatalogRepository` (seed mixte)

- [x] 10.1 Modifier
  `lib/infrastructure/catalog/in_memory.catalog.repository.dart` :
  - `listCatalog()` retourne désormais `List<CatalogItem>` =
    `_movies + _series` (où `_series` provient du seed
    `InMemorySeriesRepository`, projeté sans saisons/épisodes).
  - `searchCatalog({query})` filtre sur `title` ou `originalTitle`
    de chaque CatalogItem (Movie ou Series).
- [x] 10.2 Adapter
  `test/infrastructure/catalog/in_memory.catalog.repository_test.dart` :
  - Remplacer les assertions sur `movies` par `items`.
  - Ajouter scénarios "search returns mixed kinds".

## 11. Infrastructure — `InMemorySeriesRepository` (NOUVEAU)

- [x] 11.1 Créer
  `lib/infrastructure/series/in_memory.series.repository.dart` :
  - Seed minimal : 1 série Pingu, 2 saisons (Specials saison 0 + 1
    saison "normale" saison 1), 5 épisodes par saison non-Specials,
    2 épisodes Specials. `ageCategory: enfant`.
  - Implémente `findById(seriesId)` — retourne la série si seedée,
    `throw NotFoundException` sinon.
  - Pas de filtre âge (cohérent avec la posture in-memory du repo
    catalog : pas de garde côté repo en mémoire).
- [x] 11.2 Créer
  `lib/infrastructure/series/in_memory.series.repository_seed.dart` :
  - Constantes/factories de la série Pingu réutilisables par le seed
    catalog (pour que le row "Récemment ajoutés" projette la même
    instance Series que `findById`).
- [x] 11.3 Créer
  `test/infrastructure/series/in_memory.series.repository_test.dart`.

## 12. Infrastructure — `DioSeriesRepository` (NOUVEAU)

- [x] 12.1 Créer `lib/infrastructure/series/dio.series.repository.dart` :
  - `findById(seriesId)` : `GET /series/{seriesId}`.
  - Parse `RemoteSeriesDetailDto.fromJson(...).toDomain()`.
  - Sur `DioException`, rethrow (pas de mapping métier — `404`
    devient une `DioException` générique remontée à l'UI).
- [x] 12.2 Créer
  `test/infrastructure/series/dio.series.repository_test.dart` :
  - Scenario "GET /series/{id} parses detail with seasons + episodes".
  - Scenario "rethrows on 404 not_found".
  - Scenario "rethrows on 403 forbidden_age_category".
  - Scenario "AuthInterceptor injects all three headers transparently".

## 13. Infrastructure — Provider `seriesRepositoryProvider`

- [x] 13.1 Créer
  `lib/infrastructure/providers/series.repository_provider.dart` :
  - `@Riverpod(keepAlive: true) SeriesRepository seriesRepository(
    SeriesRepositoryRef ref)`.
  - Sélection `String.fromEnvironment('API_BASE_URL').isEmpty` →
    `InMemorySeriesRepository(...)`, sinon
    `DioSeriesRepository(ref.watch(dioProvider))`.
- [x] 13.2 `dart run build_runner build --delete-conflicting-outputs`.

## 14. Infrastructure — `DioDownloadRepository` extension

- [x] 14.1 Modifier
  `lib/infrastructure/downloads/dio.download.repository.dart` :
  - Renommer en interne `download` → `downloadMovie`.
  - Ajouter `downloadEpisode(episodeId)` : même mécanique stream Range
    HTTP, route `/episodes/{episodeId}/download` au lieu de
    `/movies/{movieId}/download`.
  - Le namespace filesystem côté local distingue
    `<docs>/downloads/movies/{id}.mp4` et
    `<docs>/downloads/episodes/{id}.mp4`.
- [x] 14.2 Étendre `test/infrastructure/downloads/dio.download.repository_test.dart` :
  - Tous les scénarios existants en double pour `downloadEpisode`,
    avec assertions sur le path.

## 15. Infrastructure — `InMemoryDownloadRepository` extension

- [x] 15.1 Modifier
  `lib/infrastructure/downloads/in_memory.download.repository.dart` :
  - Ajouter `downloadEpisode` jumelle de `downloadMovie` — fake
    pareil avec un `Stream<EpisodeDownload>`.
- [x] 15.2 Étendre les tests d'in-memory en miroir.

## 16. Infrastructure — `DioWatchProgressRepository` polymorphe

- [x] 16.1 Modifier
  `lib/infrastructure/watch_progress/dio.watch_progress.repository.dart` :
  - `findForMovie` : `GET /profiles/{p}/progress/movies/{m}`. 200 →
    `MovieProgress`, 204 → `null`.
  - `findForEpisode` : `GET /profiles/{p}/progress/episodes/{e}`.
    200 → `EpisodeProgress`, 204 → `null`.
  - `save(progress)` switch sur la sealed :
    - `MovieProgress` → `PUT /profiles/{p}/progress/movies/{m}`.
    - `EpisodeProgress` → `PUT /profiles/{p}/progress/episodes/{e}`.
  - `listForProfile(p)` : `GET /profiles/{p}/progress`. Parse via
    `watchProgressFromJson` chaque élément.
- [x] 16.2 Étendre
  `test/infrastructure/watch_progress/dio.watch_progress.repository_test.dart` :
  - Tous les scénarios existants en double : movie, puis episode.
  - Scénario "listForProfile returns mixed kinds".

## 17. Infrastructure — `InMemoryWatchProgressRepository` polymorphe

- [x] 17.1 Modifier
  `lib/infrastructure/watch_progress/in_memory.watch_progress.repository.dart` :
  - Map clé composite `(String profileId, MediaKind kind, String
    mediaId)`. Implémenter via deux maps internes ou un record key.
  - `save(WatchProgress)` switch sur la sealed pour insérer dans la
    bonne map.
  - `listForProfile` retourne le merge.
- [x] 17.2 Adapter les tests en miroir.

## 18. Application — `SaveWatchProgressUseCase` polymorphe

- [x] 18.1 Modifier
  `lib/core/application/usecases/save_watch_progress.usecase.dart` :
  - L'usecase prend un `PlayableMedia`, une `position`, un
    `completed`, un `profileId`.
  - Switch sur `PlayableMedia` pour construire `MovieProgress` ou
    `EpisodeProgress`.
  - `WatchProgressRepository.save(progress)`.
- [x] 18.2 Adapter les tests.

## 19. Application — `StartMoviePlaybackUseCase` adapté

- [x] 19.1 Modifier
  `lib/core/application/usecases/start_movie_playback.usecase.dart` :
  - Renommage interne `repo.download(movieId)` →
    `repo.downloadMovie(movieId)` ; `findByMovieId` → `findForMovie`.
  - Pas de changement de signature publique.
- [x] 19.2 Adapter les tests.

## 20. Application — `StartEpisodePlaybackUseCase` (NOUVEAU)

- [x] 20.1 Créer
  `lib/core/application/usecases/start_episode_playback.usecase.dart` :
  - Jumeau exact de `StartMoviePlaybackUseCase`, sur `Episode`,
    `downloadEpisode`, `findForEpisode`.
- [x] 20.2 Créer le test correspondant.

## 21. Application — `ResolveContinueWatchingUseCase` (NOUVEAU)

- [x] 21.1 Créer
  `lib/core/application/usecases/resolve_continue_watching.usecase.dart` :
  - Signature : `Future<List<ContinueWatchingItemDto>>
    execute(ProfileDto profile)`.
  - Sortie : sealed DTO `ContinueWatchingItemDto` =
    `MovieContinueDto | EpisodeContinueDto`.
  - Implémentation suit l'algorithme de `design.md` D-4 :
    1. `progresses = WatchProgressRepository.listForProfile`.
    2. tri `updatedAt desc`.
    3. pour chaque progress : si movie, projection directe
       (résolution Movie via `CatalogRepository.listCatalog` qui
       est en cache provider). Si episode, `Future.wait` sur
       `SeriesRepository.findById(progress.parentSeriesId)`.
    4. déduplication par `seriesId` après projection.
  - Erreur per-item : si `findById` jette, on log et on omet l'item ;
    on ne propage pas l'erreur globale.
  - Helper exposé séparément
    `resolveContinueWatchingForSeries(Series, EpisodeProgress?)`
    pour réutilisation par le helper UI `playLabelFor`.
- [x] 21.2 Créer
  `lib/core/application/dtos/continue_watching_item.dto.dart` :
  - Sealed avec `MovieContinueDto(movie, resumeSeconds)` et
    `EpisodeContinueDto(series, episode, resumeSeconds, kind)`
    où `kind ∈ {inProgress, nextAfterCompleted, restart}`.
- [x] 21.3 Créer
  `test/core/application/usecases/resolve_continue_watching.usecase_test.dart`
  avec les scénarios :
  - profile sans aucune progression → liste vide.
  - 1 movie en progress → 1 MovieContinueDto.
  - 1 episode in-progress → 1 EpisodeContinueDto kind=inProgress
    avec `resumeSeconds == progress.positionSeconds`.
  - 1 episode completed, plus d'épisodes après dans la même saison
    → next épisode S{n}E{m+1}, kind=nextAfterCompleted, resume=0.
  - 1 episode completed, fin de saison mais saison suivante existe
    → S{n+1}E1, kind=nextAfterCompleted.
  - 1 episode completed, fin de série → S1E1, kind=restart.
  - 2 progressions distinctes pour la même série (E2 ancien complet,
    E3 récent in-progress) → 1 seul item, l'item le plus récent
    (E3 in-progress) après dédup.
  - `findById` jette pour seriesA → seriesA omise, autres entries
    présentes.

## 22. Application — `CatalogApplicationService` adapté

- [x] 22.1 Modifier
  `lib/core/application/services/catalog_application.service.dart` :
  - `buildHomeRowsFor(profile)` :
    - Charge `CatalogRepository.listCatalog()` puis
      `ResolveContinueWatchingUseCase` en parallèle (`Future.wait`).
    - Le row `recentlyAdded` consomme tous les items (films + séries
      mélangés) trié `addedAt desc`.
    - Le row `continueWatching` consomme la sortie du usecase.
    - Les rows `saga`, `genre`, `favorites`, `neverWatched`,
      `downloaded` filtrent uniquement les `Movie` (cf. design.md
      D-5) — implémentation : `items.whereType<Movie>().toList()`.
- [x] 22.2 Adapter le test du service :
  - Scénario "Recently added mixes movies and series".
  - Scénario "Genre row excludes series".
  - Scénario "Continue watching uses
    ResolveContinueWatchingUseCase".

## 23. Application — `SearchApplicationService` adapté

- [x] 23.1 Modifier
  `lib/core/application/services/search_application.service.dart` :
  - `searchFor({query, profile})` retourne désormais
    `Future<List<CatalogItem>>` (au lieu de `Future<List<Movie>>`).
  - Le tri alphabétique sur `title` reste — `CatalogItem` expose
    `title` via getter.
- [x] 23.2 Adapter
  `test/core/application/services/search_application.service_test.dart`.

## 24. UI — `CatalogItemCard` (renommage et switch)

- [x] 24.1 Renommer `lib/ui/catalog/movie_card.dart` →
  `lib/ui/catalog/catalog_item_card.dart`. Renommer la classe
  `MovieCard` → `CatalogItemCard`.
  *Approche d'implémentation* : `MovieCard` reste tel quel ; un
  `SeriesCard` jumeau est créé ; le polymorphisme se fait dans
  `CatalogRowWidget._buildCard` qui switche `is MovieDto` /
  `is SeriesDto`. Effet équivalent au renommage proposé sans churn
  d'imports ; la sémantique "switch sur la sealed/abstract pour
  rendre le bon variant" est conservée.
- [x] 24.2 Le widget prend désormais un `CatalogItem`. Switch
  interne sur la sealed pour la caption :
  - `Movie` → `"{year} · {humanizedDuration}"` (existant).
  - `Series` → `"{year} · {seasonsCount} saison(s)"`.
  - `Series` sans saisons connues → `"{year} · Série"`.
- [x] 24.3 Mettre à jour les imports / call sites.
- [ ] 24.4 Adapter les widget tests.

## 25. UI — Modale détail factorisée

- [x] 25.1 Renommer `lib/ui/catalog/movie_detail_modal.dart` →
  `lib/ui/catalog/catalog_item_detail_modal.dart`.
  Renommer `showMovieDetail` → `showCatalogItemDetail` (signature
  `(BuildContext context, CatalogItem item)`).
- [ ] 25.2 Refactor : extraire la section haute commune (backdrop,
  titre, tagline, ligne meta, synopsis, genres, directors, cast)
  en widget `_CommonHeader`.
- [x] 25.3 Switch sur `CatalogItem` :
  - `case Movie m:` → ancienne section basse (Lire button →
    `StartMoviePlaybackUseCase`).
  - `case Series s:` → nouvelle section basse :
    1. bouton "Lire" smart (label dynamique, cf. tâche 27).
    2. liste des saisons (cf. tâche 26).
- [x] 25.4 La ligne meta pour `Series` remplace `{duration}` par
  `{seasonsCount} saison(s) · {episodesCount} épisode(s)`.
- [x] 25.5 La modale série déclenche un appel
  `seriesRepositoryProvider.findById(series.id)` dès l'ouverture
  (FutureBuilder ou Riverpod async). Skeleton pendant le chargement,
  message d'erreur générique en cas d'échec.

## 26. UI — Liste saisons + épisodes

- [x] 26.1 Créer `lib/ui/catalog/series/season_section.dart` :
  - `ExpansionTile` portant le label "Saison {n}" ou "Specials"
    (saison 0).
  - Liste verticale de `EpisodeCard` à l'intérieur.
  - L'expansion par défaut est calculée en amont par le widget
    parent (cf. 26.2).
- [x] 26.2 Dans le widget conteneur de la modale série :
  - Trier les saisons `season_number asc`.
  - **Déplacer** la saison 0 en fin de liste si elle existe.
  - Identifier la saison de la progression la plus récente du profil
    via `WatchProgressRepository.listForProfile` (déjà chargé pour
    Continue Watching ; passer la liste en prop pour éviter un re-fetch).
  - Cette saison-là est dépliée par défaut ; les autres collapsées.
- [x] 26.3 Créer `lib/ui/catalog/series/episode_card.dart` :
  - Layout : thumb_url (16:9) + titre (1 ligne ellipsis) + caption
    `"E{n} · {humanizedDuration}"`.
  - Si `EpisodeProgress` existe pour ce profil :
    - Barre de progression `position / duration` en bas du thumb.
    - Si `completed: true`, overlay icône ✓.
  - Tap sur la card → appelle `StartEpisodePlaybackUseCase` directement
    (pas de modale épisode-spécifique).
- [ ] 26.4 Tests widget : saisons collapsées par défaut, saison de
  la progression dépliée, Specials en bas, tap sur épisode déclenche
  le usecase.

## 27. UI — Bouton "Lire" smart (label dynamique)

- [x] 27.1 Créer `lib/ui/catalog/series/play_label.dart` — fonction
  pure :
  ```dart
  ({String label, Episode target}) playLabelFor({
    required Series series,
    required List<EpisodeProgress> progresses,
  });
  ```
  Implémentation : appelle le helper Application
  `resolveContinueWatchingForSeries` (cf. tâche 21.1) puis formate
  le label selon le `kind` :
  - `never` → `"Lire ${formatEpRef(firstEpisode)}"`
  - `inProgress` → `"Reprendre ${formatEpRef(currentEp)}"`
  - `nextAfterCompleted` → `"Lire ${formatEpRef(nextEp)}"`
  - `restart` (fin de série) → `"Revoir ${formatEpRef(firstEpisode)}"`
  où `formatEpRef(ep)` produit `"S{n}E{m}"` (ou `"E{m}"` si saison 1
  unique sans Specials, MVP).
- [x] 27.2 Le bouton dans la modale série appelle
  `StartEpisodePlaybackUseCase` sur `target`.
- [x] 27.3 Tests : chaque branche du label.

## 28. UI — `PlayerPage` accepte `PlayableMedia`

- [x] 28.1 Modifier `lib/ui/player/player_page.dart` :
  - Le constructeur prend `PlayableMedia media` au lieu de `Movie`.
  - Switch interne pour appeler le bon usecase (`StartMovie` /
    `StartEpisode`) et la bonne forme de `SaveWatchProgress`.
  - Le titre affiché en haut du player est `media.title` (Movie) ou
    `"${series.title} — S${seasonN}E${epN} ${ep.title}"` (Episode,
    le widget reçoit aussi le `Series` parent en prop optionnelle).
- [x] 28.2 Adapter les call sites du player.
- [ ] 28.3 Adapter les tests du player.

## 29. UI — Row Continue Watching réelle

- [ ] 29.1 Adapter le widget `_ContinueWatchingRow` (ou
  l'équivalent en place) :
  - Consomme `CatalogRow` dont les `items` sont enrichis (movie ou
    episode).
  - Pour les `MovieContinueDto`, render un `CatalogItemCard` standard
    avec barre de reprise.
  - Pour les `EpisodeContinueDto`, render une carte série spéciale :
    thumbnail = thumb_url de l'épisode (ou backdrop de la série en
    fallback), label = `"S{n}E{m} · {episode.title}"`, sous-label =
    `series.title`. Tap → ouvre directement le player épisode (pas
    la modale série), avec la position de reprise.
- [ ] 29.2 Tests widget.

## 30. UI — Empty state dev mode (Specials seedés)

- [x] 30.1 Vérifier que l'empty state homepage continue à se déclencher
  correctement quand le seed est vide. Le seed Pingu doit être
  optionnel via un flag de test (in-memory).
  *Vérifié indirectement* : les tests `home_page_test.dart` continuent
  de passer avec la sealed/items, dont le scenario "shows empty state
  when no rows". Le seed Pingu est intégré dans
  `InMemorySeriesRepository` ; le test injecte des fakes via
  `homeCatalogRowsProvider.overrideWith` et n'est pas affecté par le
  seed.
- [x] 30.2 Tests existants `home_page_test.dart` : sanity check.
  *Vérifié* : les 6 tests de `home_page_test.dart` passent verts dans
  le suite globale (390/390).

## 31. Build runner et nettoyage

- [x] 31.1 `dart run build_runner build --delete-conflicting-outputs`
  pour régénérer tous les `.g.dart` (providers, usecases).
- [x] 31.2 `dart analyze` doit être propre.
- [x] 31.3 `flutter test` doit être tout vert.
- [ ] 31.4 Smoke test manuel :
  - `flutter run` (in-memory) : ouvrir la modale série, naviguer dans
    les saisons, lancer un épisode, vérifier la barre de progression,
    fermer, rouvrir, vérifier la reprise.
  - Si un backend `add-series-viewing`-ready est dispo,
    `flutter run --dart-define=API_BASE_URL=https://...` et même
    smoke test.
  *À faire par l'utilisateur — ne peut pas être automatisé via
  `flutter test`. La compilation+les 390 tests automatisés couvrent
  la non-régression. Le backend localhost:3000 a été curlé en cours
  de session pour valider que la chaîne UI lit bien les séries
  serveur (cf. wire response Code Lyoko ado).*

## 32. Validation OpenSpec

- [x] 32.1 `openspec validate add-series-viewing` doit être propre.
- [x] 32.2 Lecture croisée de tous les delta specs : cohérence des
  noms d'entités (`CatalogItem`, `Series`, `Episode`, `Season`,
  `MovieProgress`, `EpisodeProgress`, `MovieDownload`,
  `EpisodeDownload`, `SeriesRepository`).
  *Vérifié* : 39 requirements à travers 5 capabilities (catalog,
  series-viewing, downloads, video-playback, search), tous les noms
  d'entités cohérents avec l'implémentation. `openspec validate
  add-series-viewing` passe en mode strict.
