## 1. Application — `RemoteWatchProgressDto`

- [x] 1.1 Créer `lib/core/application/dtos/remote_watch_progress.dto.dart` :
  - Classe `RemoteWatchProgressDto` avec champs `final String profileId`, `final String movieId`, `final int positionSeconds`, `final bool completed`, `final DateTime updatedAt`. Constructeur `const`.
  - `factory RemoteWatchProgressDto.fromJson(Map<String, dynamic> json)` : parse les clés snake_case (`profile_id`, `movie_id`, `position_seconds`, `completed`, `updated_at`). `updated_at` parse via `DateTime.parse(...)`. Cast direct sans coercion défensive sur les autres champs (fail-fast comme les autres DTOs).
  - `WatchProgress toDomain()` : mappage 1:1 vers le constructeur Domain.
  - `Map<String, dynamic> toWireBody()` : produit `{position_seconds, completed, updated_at: updatedAt.toUtc().toIso8601String()}`. **N'inclut pas** `profile_id` ni `movie_id` (présents dans le path URL).
  - Doc-comment : "Wire-format DTO mediating between the JSON payload of the three watch-progress endpoints (cf. `API.md` § Progression de lecture) and the Domain `WatchProgress` entity. `fromJson`/`toDomain` for GET responses, `toWireBody()` for the PUT request body."
  - Imports : `package:kidflix/core/domain/model/watch_progress.dart`.

- [x] 1.2 Créer `test/core/application/dtos/remote_watch_progress.dto_test.dart` :
  - **fromJson + toDomain** : construit un DTO depuis un payload conforme à `API.md`, vérifie que `toDomain()` produit un `WatchProgress` avec les bons champs (notamment `updatedAt` parsé en UTC).
  - **toWireBody** : construit un DTO, vérifie que `toWireBody()` produit `{position_seconds: 1900, completed: false, updated_at: "2026-04-22T10:30:10.000Z"}` et **ne contient pas** les clés `profile_id` ni `movie_id`.
  - **Round-trip** : `fromJson(toWireBody() ∪ {profile_id, movie_id}).toDomain()` redonne un `WatchProgress` égal à l'original.
  - **fromJson fail-fast on missing field** : payload sans `position_seconds` → cast/null error à parse.

## 2. Infrastructure — `DioWatchProgressRepository`

- [x] 2.1 Créer `lib/infrastructure/watch_progress/dio.watch_progress.repository.dart` :
  - Classe `DioWatchProgressRepository implements WatchProgressRepository`.
  - Constructeur `DioWatchProgressRepository({required Dio dio})`. Champ `final Dio _dio`.
  - `findFor({required String profileId, required String movieId})` :
    - `final response = await _dio.get('/profiles/$profileId/progress/$movieId');`
    - `if (response.statusCode == 204 || response.data == null) return null;`
    - `return RemoteWatchProgressDto.fromJson(response.data as Map<String, dynamic>).toDomain();`
  - `save(WatchProgress progress)` :
    - Construire un `RemoteWatchProgressDto` à partir du `progress` reçu (5 champs scalaires, mapping direct).
    - `await _dio.put('/profiles/${progress.profileId}/progress/${progress.movieId}', data: dto.toWireBody());`
    - Discard la réponse. Retour `Future<void>`.
  - `listForProfile(String profileId)` :
    - `final response = await _dio.get('/profiles/$profileId/progress');`
    - `final list = (response.data as Map<String, dynamic>)['progress'] as List<dynamic>;`
    - Mapper chaque élément via `RemoteWatchProgressDto.fromJson(...).toDomain()`.
    - Retourner la liste (non-growable).
  - **Aucun try/catch métier** : toute `DioException` se propage à l'appelant.
  - **Le repo ne touche jamais** aux headers `Authorization` ou `X-Device-Id` (responsabilité de l'`AuthInterceptor`).
  - Doc-comment de classe : "HTTP implementation of `WatchProgressRepository` backed by Dio. Hits the three endpoints documented in `API.md` § Progression de lecture (`GET`, `PUT`, `GET liste`). `findFor` treats `204 No Content` as `null` per the API contract. The required `Authorization: Bearer <jwt>` and `X-Device-Id: <uuid>` headers are injected transparently by the `AuthInterceptor` registered on `dioProvider` — this repository never touches headers explicitly. No metier-level error mapping: any `4xx`/`5xx`/network error surfaces as a generic `DioException` (same posture as `DioCatalogRepository`)."
  - Imports : `package:dio/dio.dart`, `package:kidflix/core/application/dtos/remote_watch_progress.dto.dart`, `package:kidflix/core/domain/model/watch_progress.dart`, `package:kidflix/core/domain/services/watch_progress.repository.dart`.

- [x] 2.2 Créer `test/infrastructure/watch_progress/dio.watch_progress.repository_test.dart` :
  - Pattern `_FakeAdapter` réutilisé verbatim depuis `test/infrastructure/catalog/dio.catalog.repository_test.dart` (le mieux : copier-coller la classe `_FakeAdapter` + helpers `_jsonResponse`, `_emptyResponse`, `_makeDio`).
  - **findFor — 200 returns parsed progress** : adapter répond 200 avec un payload conforme à `API.md`. Vérifier que la requête capturée a `method == GET`, `path == '/profiles/p1/progress/m1'`. Vérifier que le `WatchProgress` retourné a les bons champs.
  - **findFor — 204 returns null** : adapter répond 204 avec body vide → résultat `null`.
  - **findFor — 200 with null body returns null** : adapter répond 200 avec `data: null` (défensive) → résultat `null`.
  - **save — PUT with snake_case body** : appel `save(WatchProgress(...))`. Vérifier que la requête capturée a `method == PUT`, `path == '/profiles/p1/progress/m1'`, et que le body est `{position_seconds: 1900, completed: false, updated_at: "..."}` (sans `profile_id` ni `movie_id`).
  - **save — discards response body** : adapter répond 200 avec un payload différent du body envoyé. `save` retourne `Future<void>` sans erreur, sans tenter de parser la réponse.
  - **listForProfile — empty array returns empty list** : adapter répond 200 avec `{"progress": []}`. Résultat : liste vide.
  - **listForProfile — non-empty array maps each entry** : adapter répond 200 avec `{"progress": [{...}, {...}]}`. Vérifier que chaque entrée est correctement convertie en `WatchProgress`. Vérifier que le path est `/profiles/p1/progress`.
  - **4xx surfaces as DioException** : adapter répond 404 sur `findFor`. Vérifier que l'appel throw `DioException`. Idem pour `save` sur 500 et `listForProfile` sur 401.
  - **No auth header is set explicitly by the repo** : le `_makeDio` du test ne registre pas d'`AuthInterceptor`. Vérifier que les requêtes capturées n'ont **pas** de header `Authorization` (preuve structurelle que c'est l'interceptor qui les ajoute en prod, pas le repo).

## 3. Infrastructure — Switch in-memory ↔ HTTP

- [x] 3.1 Modifier `lib/infrastructure/providers/watch_progress.repository_provider.dart` :
  - Lire `const baseUrl = String.fromEnvironment('API_BASE_URL');` en tête de fonction.
  - Si `baseUrl.isEmpty` : retourner `InMemoryWatchProgressRepository()` (comportement actuel inchangé).
  - Sinon : retourner `DioWatchProgressRepository(dio: ref.watch(dioProvider))`.
  - Mettre à jour le doc-comment : décrire les deux modes (mirror du doc de `download.repository_provider.dart`).
  - Ajouter les imports nécessaires (`dio.provider.dart`, `dio.watch_progress.repository.dart`).

- [x] 3.2 Lancer `dart run build_runner build --delete-conflicting-outputs` pour régénérer `watch_progress.repository_provider.g.dart`.

## 3bis. UI — Save-on-seek dans `PlayerPage`

- [x] 3bis.1 Modifier `lib/ui/pages/player/player.page.dart` :
  - Ajouter `const Duration _seekDetectionThreshold = Duration(seconds: 2);` à côté des constants existantes.
  - Ajouter un champ `Duration? _lastObservedPosition;` dans `_PlayerPageState`.
  - Dans le listener `engine.positionStream`, capturer `previous = _lastObservedPosition` avant le `setState`, mettre à jour `_lastObservedPosition = p` après, et si `previous != null && (p - previous).abs() > _seekDetectionThreshold`, déclencher `unawaited(_saveProgressNow())` avant l'appel à `_checkCompletion()`.
  - Pas de modification de `_saveProgressNow` ni du timer périodique : le guard `_saving` coalesce naturellement les saves concurrents.

- [x] 3bis.2 Corriger `lib/ui/pages/player/media_kit_player_engine.dart` :
  - Remplacer `_player.open(...)` + `_player.seek(initialPosition)` par un seul `_player.open(Media('file://$filePath', start: initialPosition > Duration.zero ? initialPosition : null), play: false)`.
  - Raison : le `seek()` post-`open()` est silencieusement ignoré sur iOS si le demuxer n'est pas prêt. `Media.start` passe le paramètre `--start=N` à mpv qui l'applique atomiquement dans la phase d'open. Ce bug ne se voyait pas tant que la progression était in-memory (la dialog resume ne se déclenchait jamais cross-restart).
  - Commentaire dans le code expliquant le pourquoi.

## 4. Vérification

- [x] 4.1 `flutter analyze` vert.

- [x] 4.2 `flutter test` vert. Suite complète, en particulier :
  - `test/core/application/dtos/remote_watch_progress_dto_test.dart` (nouveau)
  - `test/infrastructure/watch_progress/dio.watch_progress.repository_test.dart` (nouveau)
  - `test/infrastructure/watch_progress/in_memory_watch_progress_repository_test.dart` (existant — non-régression, contrat préservé)
  - `test/core/application/usecases/get_watch_progress_usecase_test.dart`, `save_watch_progress_usecase_test.dart` (existants — non-régression)
  - `test/core/domain/model/watch_progress_test.dart` (existant si présent — non-régression)
  - `test/infrastructure/auth/dio.auth.repository_test.dart`, `test/infrastructure/catalog/dio.catalog.repository_test.dart`, `test/infrastructure/profile_management/dio.profile_management.repository_test.dart`, `test/infrastructure/downloads/dio.download.repository_test.dart` (existants — non-régression, leur `Dio` n'est pas affecté)
  - Tests UI consommateurs (`test/ui/pages/player/...`) : non-régression sur le résume dialog et la save périodique.

- [x] 4.3 Lancement manuel **mode in-memory** (sans flag) : `flutter run`. Vérifier que :
  - Le flow OTP → sélection profil → home → ouverture détail → `"Lire"` lance la lecture comme avant.
  - La progression se sauvegarde en RAM pendant la session (vérifier qu'au sein d'une même session, fermer le player et le rouvrir affiche bien le dialogue *"Reprendre la lecture ?"*).
  - Tuer l'app et la relancer : la progression est perdue (comportement attendu en in-memory). Le dialogue n'apparaît pas au prochain lancement du même film.

- [x] 4.4 Lancement manuel **mode HTTP** contre un backend local qui implémente les trois endpoints :
  - iOS Simulator : `flutter run --dart-define=API_BASE_URL=http://localhost:8080`
  - Android emulator : `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`
  - Login OTP, sélection profil, ouverture d'un film.
  - **Cas nominal save périodique** : vérifier dans les logs / DevTools Network qu'une requête `PUT http://localhost:8080/profiles/{pid}/progress/{mid}` est émise environ toutes les 10s pendant la lecture, avec headers `Authorization: Bearer ...`, `X-Device-Id: ...`, et body `{position_seconds, completed, updated_at}` snake_case.
  - **Cas nominal save final on dispose** : fermer le player → vérifier qu'un dernier `PUT` est émis avec la position courante.
  - **Cas nominal completion à 90%** : laisser la lecture passer le seuil 90% → vérifier qu'un `PUT` avec `completed: true` est émis.
  - **Cross-restart resume — le test critique** : tuer l'app pendant la lecture → relancer → ouvrir le même film → vérifier que `GET http://localhost:8080/profiles/{pid}/progress/{mid}` est émis au mount du `PlayerPage` → vérifier que le dialogue *"Reprendre la lecture ?"* apparaît avec la position correcte → vérifier que tap *"Reprendre à X min"* seek à la position stockée.
  - **204 sur fresh movie** : ouvrir un film jamais regardé → vérifier que `GET /progress/{mid}` répond `204` → vérifier qu'aucun dialogue n'apparaît, lecture commence à 0.
  - **listForProfile non utilisé en prod** : aucun appel `GET /profiles/{pid}/progress` (sans movieId) ne devrait être émis pendant le flow nominal — la rangée *"Continuer à regarder"* reste un placeholder.
  - **Coupure réseau pendant save** : désactiver le wifi pendant la lecture → vérifier que les `PUT` échouent silencieusement (logs `DioException`) sans crasher l'app, et que la lecture continue normalement. Ré-activer le wifi → le tick suivant retente.
  - **Multi-device upsert** : sur un device A, regarder jusqu'à 5 min, fermer. Sur device B, ouvrir le même film → le dialogue propose la position de A. Reprendre, regarder jusqu'à 10 min, fermer. Re-ouvrir sur A → le dialogue propose maintenant 10 min (la position du dernier `PUT` gagne).
  - **Save on seek** : pendant la lecture, scrubber le seek bar à une position différente (forward et backward). Vérifier qu'un `PUT /progress/{mid}` est émis **immédiatement** après le seek (pas à attendre les 10s suivantes), avec `position_seconds` à la nouvelle valeur. Vérifier qu'aucun `PUT` parasite n'est émis pendant la lecture normale (uniquement les ticks 10s entre deux seeks).

- [x] 4.5 `openspec validate add-http-watch-progress-repository --strict` vert.
