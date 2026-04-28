## 1. Infrastructure — Helper partagé `streamHttpDownload` + `inspectDownloadOnDisk`

- [x] 1.1 Créer `lib/infrastructure/downloads/http_download_stream.dart` :
  - Fonction top-level publique `Stream<MovieDownload> streamHttpDownload({required Dio dio, required String url, required String movieId, required Directory downloadsDir, required CancelToken cancelToken, required bool Function() isCancelled})`. Implémentation : extraire verbatim la boucle `_runDownload` de `in_memory.download.repository.dart` (lignes 134-296) en remplaçant :
    - le membre `_dio` par le paramètre `dio`,
    - la const `stubUrl` par le paramètre `url`,
    - les helpers privés `_finalPath` / `_partialPath` / `_resolveDir` par des constructions inline à partir du `downloadsDir` reçu,
    - le `_active.remove(movieId)` final (responsabilité de l'appelant — le helper close son controller mais ne touche pas au map du repo).
  - Fonction top-level publique `Future<MovieDownload?> inspectDownloadOnDisk({required String movieId, required Directory downloadsDir})`. Implémentation : extraire verbatim la logique d'inspection FS de `findByMovieId` (lignes 53-77) — tester `final.mp4` puis `partial.mp4`, retourner `null` sinon.
  - Helpers privés `_finalPath(movieId, dir)` et `_partialPath(movieId, dir)` (file-private), réutilisés par les deux fonctions publiques pour garantir la cohérence des noms.
  - Constants partagées au niveau du fichier : `const _readyThresholdBytes = 2 * 1024 * 1024;`, `const _readyThresholdFraction = 0.03;`, `const _throttleInterval = Duration(milliseconds: 250);`. Plus aucun usage de ces constants dans les classes repo.
  - Imports : `dart:async`, `dart:io`, `dart:typed_data`, `package:dio/dio.dart`, `package:kidflix/core/domain/model/movie_download.dart`.
  - L'override `Options(responseType: ResponseType.stream, receiveTimeout: Duration.zero)` est posé **dans le helper**, à chaque appel `dio.get`, pour ne jamais muter `dio.options` (les autres repos qui partagent le `Dio` central ont besoin de `responseType: json`).
  - Doc-comment : "Shared download streaming primitive used by every `DownloadRepository` implementation. Each caller provides its own `Dio` so an in-memory repo can hit a third-party URL without leaking auth headers, while a backend-bound repo can hit a relative path under `dio.options.baseUrl` and rely on the registered `AuthInterceptor`. The helper is the single source of truth for the `.partial` → `.mp4` rename, the 2 MiB + 3% `readyToPlay` threshold, the 4 Hz progress throttling, and the `Range` resume semantics."

- [x] 1.2 Créer `test/infrastructure/downloads/http_download_stream_test.dart` :
  - Pattern `_FakeAdapter` (cf. `dio.auth.repository_test.dart` ou `dio.catalog.repository_test.dart`) qui retourne un `ResponseBody` streamé à partir d'une `List<List<int>>` de chunks.
  - Helper `_tempDownloadsDir()` créant un `Directory.systemTemp.createTemp('kidflix_downloads_test_')`.
  - **Fresh download to completion** : adapter répond 200 avec `Content-Length: 10485760` (10 MB) et un stream de chunks. Le helper émet `downloading` initial → `readyToPlay` → final `complete`. Le fichier `${dir}/abc.mp4` existe à la fin avec la bonne taille, le `.partial` n'existe plus.
  - **Resume from existing .partial via Range** : pré-créer un `${dir}/abc.mp4.partial` de 30 Mo. Adapter répond 206 avec `Content-Range: bytes 30000000-99999999/100000000`. Vérifier que la requête sortante a `Range: bytes=30000000-` ; vérifier que le premier event a `bytesReceived == 30000000` et `bytesTotal == 100000000`.
  - **Server ignores Range, restart from 0** : pré-créer un `.partial` de 30 Mo. Adapter répond 200 (ignore le Range). Vérifier que le `.partial` est tronqué à 0 ; le premier event a `bytesReceived == 0`.
  - **Existing complete .mp4 short-circuits HTTP** : pré-créer un `${dir}/abc.mp4` de 10 Mo. Le helper émet un seul `complete` et close, sans appeler l'adapter (vérifier via le compteur de requêtes du `_FakeAdapter`).
  - **Dio defaults are not mutated** : `dio.options.responseType == json` et `dio.options.receiveTimeout == 30s` avant l'appel ; après un download terminé, ces options restent inchangées.
  - **Network error emits failed and preserves .partial** : pré-créer un `.partial` de 5 Mo. Adapter raise un `DioException(type: connectionError)`. Final event `failed` avec `errorMessage` non-null ; `.partial` existe encore avec ≥ 5 Mo.
  - **CancelToken triggers cancelled and preserves .partial** : démarrer un download long, `cancelToken.cancel()` à mi-stream. Final event `cancelled` avec `localPath` pointant sur le `.partial` ; le fichier `.partial` existe encore.
  - **`inspectDownloadOnDisk` returns complete** : pré-créer un `${dir}/abc.mp4` de 50 Mo → résultat `MovieDownload(status: complete, bytesReceived: 50e6, bytesTotal: 50e6, localPath: <abs path>)`.
  - **`inspectDownloadOnDisk` returns cancelled** : pré-créer un `.partial` seul, 30 Mo → résultat `cancelled`, `bytesTotal == null`.
  - **`inspectDownloadOnDisk` returns null** : aucun fichier → résultat `null`.

## 2. Infrastructure — Refactor de `InMemoryDownloadRepository` vers le helper

- [x] 2.1 Modifier `lib/infrastructure/downloads/in_memory.download.repository.dart` :
  - Conserver la const publique `static const String stubUrl = '…archive.org…'` et son doc-comment justifiant le choix (Big Buck Bunny, durée, redirect 302, etc.).
  - Conserver le constructeur `InMemoryDownloadRepository({Dio? dio, Directory? downloadsDirectory})` — signature publique inchangée.
  - Supprimer les constants `_readyThresholdBytes`, `_readyThresholdFraction`, `_throttleInterval` (déplacées dans le helper).
  - Supprimer la classe interne `_ActiveDownload` redondante avec ce que le helper gère ; la remplacer par un `Map<String, _ActiveDownload>` minimal qui conserve uniquement `controller`, `cancelToken`, `cancelled`, `currentSnapshot`. (Le helper gère le sink interne ; l'`_ActiveDownload` du repo gère uniquement le bridge entre le stream du helper et le controller broadcast partagé entre listeners.)
  - Réécrire `download(movieId)` :
    - Si `_active[movieId]` existe, retourner `existing.controller.stream`.
    - Sinon, créer un `StreamController.broadcast()`, un `CancelToken`, enregistrer dans `_active`. Lancer `streamHttpDownload(...)` avec `dio: _dio` (le `Dio` privé sans interceptor), `url: stubUrl`, `movieId`, `downloadsDir: await _resolveDir()`, `cancelToken`, `isCancelled: () => active.cancelled`. `.listen` sur le stream retourné, propager chaque event dans `controller` et mettre à jour `currentSnapshot`. À la complétion du stream helper, fermer `controller`, retirer `_active[movieId]`.
  - Réécrire `findByMovieId(movieId)` :
    - Si `_active[movieId]?.currentSnapshot != null`, le retourner.
    - Sinon, retourner `await inspectDownloadOnDisk(movieId: movieId, downloadsDir: await _resolveDir())`.
  - Conserver `cancel(movieId)` quasi tel quel (cancel token + `await controller.done`).
  - Conserver `delete(movieId)` quasi tel quel (cancel + suppression FS).
  - Conserver `_resolveDir()` (logique inchangée, override par tests).
  - Mettre à jour le doc-comment de classe : "In-memory `DownloadRepository` for offline / dev mode (no `--dart-define=API_BASE_URL`). Delegates the HTTP streaming loop to `streamHttpDownload(...)` and the on-disk inspection to `inspectDownloadOnDisk(...)`. The private `Dio` instance has no `AuthInterceptor` registered — this is a structural guarantee that no `Authorization: Bearer <jwt>` is ever sent to the third-party `archive.org` URL."

- [x] 2.2 Vérifier `test/infrastructure/downloads/in_memory_download_repository_test.dart` :
  - Cibler le contrat public uniquement (`download`, `findByMovieId`, `cancel`, `delete`). Les tests existants devraient passer sans modification — la façade publique est inchangée.
  - Si des tests visent un détail interne (par ex. assert sur les const `_throttleInterval` ou sur le `_runDownload`), les migrer vers le test du helper (`http_download_stream_test.dart`) ou supprimer s'ils sont redondants avec les nouveaux tests du helper.

## 3. Infrastructure — Nouvelle `DioDownloadRepository`

- [x] 3.1 Créer `lib/infrastructure/downloads/dio.download.repository.dart` :
  - Classe `DioDownloadRepository implements DownloadRepository`.
  - Constructeur `DioDownloadRepository({required Dio dio, Directory? downloadsDirectory})`. Champs `final Dio _dio`, `final Directory? _downloadsDirOverride`. État interne `Directory? _cachedDir`, `Map<String, _ActiveDownload> _active = {}`.
  - Classe privée `_ActiveDownload` identique à celle de `in_memory.download.repository.dart` (controller, cancelToken, cancelled, currentSnapshot).
  - Méthode `_resolveDir()` identique à celle de l'in-memory (override → fallback `${applicationDocumentsDirectory}/downloads`, création si absent).
  - `download(movieId)` :
    - Identique en structure à celle de l'in-memory : dedup via `_active`, sinon création du controller + cancel token, lancement de `streamHttpDownload(...)`.
    - Différence : `dio: _dio` (le `Dio` central injecté avec l'`AuthInterceptor`), `url: '/movies/$movieId/download'` (path relatif).
  - `findByMovieId(movieId)` :
    - Identique en structure à l'in-memory : check `_active` puis délégation à `inspectDownloadOnDisk(...)`. **Aucun appel HTTP**.
  - `cancel(movieId)` : identique à l'in-memory (cancel token + `await controller.done`).
  - `delete(movieId)` : identique à l'in-memory (cancel + suppression FS). **Aucun appel HTTP DELETE.**
  - Doc-comment de classe : "HTTP implementation of `DownloadRepository` backed by Dio. Hits `GET /movies/{movie_id}/download` per `API.md` § Téléchargement de fichier vidéo, with `Range` support for resume and the same on-disk layout (`${documents}/downloads/{movieId}.mp4`) as `InMemoryDownloadRepository`. The required `Authorization: Bearer <jwt>` and `X-Device-Id: <uuid>` headers are injected transparently by the `AuthInterceptor` registered on `dioProvider` — this repository never touches headers explicitly. Errors (4xx/5xx/network) are surfaced as `DownloadStatus.failed` with the dio-supplied message; no metier-level Domain exception mapping. `cancel` and `delete` operate on the local filesystem only — there is no documented backend endpoint for either."
  - Imports : `dart:async`, `dart:io`, `package:dio/dio.dart`, `package:kidflix/core/domain/model/movie_download.dart`, `package:kidflix/core/domain/services/download.repository.dart`, `package:kidflix/infrastructure/downloads/http_download_stream.dart`, `package:path_provider/path_provider.dart`.

- [x] 3.2 Créer `test/infrastructure/downloads/dio.download.repository_test.dart` :
  - Pattern `_FakeAdapter` réutilisé.
  - Helper `_tempDownloadsDir()` réutilisé.
  - **download() targets the relative path** : `dio.options.baseUrl == 'http://localhost:8080'`, l'adapter répond 200 avec un stream de 10 Mo. Vérifier que la requête capturée a `method == GET`, `path == '/movies/abc/download'`, et que la full URL est `http://localhost:8080/movies/abc/download`.
  - **download() emits readyToPlay then complete** : reproduit le scénario nominal du helper, mais via `DioDownloadRepository.download("abc")`. Validation de bout-en-bout que la classe orchestre correctement le helper.
  - **Concurrent download() shares the stream** : `download("abc")` × 2 dans la même tick → `_FakeAdapter.requestCount == 1`, les deux streams reçoivent les mêmes events.
  - **findByMovieId returns null on fresh install** : downloads dir vide, aucun download actif → `null`. Vérifier `_FakeAdapter.requestCount == 0` (aucune requête HTTP).
  - **findByMovieId returns complete for an existing .mp4** : pré-créer `${dir}/abc.mp4`. Vérifier le résultat. Vérifier `requestCount == 0`.
  - **download() emits failed on 403** : adapter répond 403 → final event `failed` avec `errorMessage` non-null.
  - **download() emits failed on 5xx** : adapter répond 500 → final event `failed`.
  - **cancel() preserves .partial without HTTP DELETE** : démarrer un download long, `cancel("abc")`. Vérifier que le `.partial` existe encore, que le final event est `cancelled`. Vérifier qu'aucune requête DELETE n'a été émise (l'adapter ne capture qu'un GET).
  - **delete() removes files without HTTP DELETE** : pré-créer un `.mp4` (ou démarrer + cancel pour générer un `.partial`), puis `delete("abc")`. Vérifier que le fichier est supprimé. Vérifier qu'aucune requête HTTP DELETE n'a été émise.

## 4. Infrastructure — Switch in-memory ↔ HTTP

- [x] 4.1 Modifier `lib/infrastructure/providers/download.repository_provider.dart` :
  - Lire `const baseUrl = String.fromEnvironment('API_BASE_URL');` en tête de fonction.
  - Si `baseUrl.isEmpty` : retourner `InMemoryDownloadRepository()` (comportement actuel inchangé).
  - Sinon : retourner `DioDownloadRepository(dio: ref.watch(dioProvider))`.
  - Mettre à jour le doc-comment : décrire les deux modes (mirror du doc de `catalog.repository_provider.dart` / `auth.repository_provider.dart` / `profile_management.repository_provider.dart`).
  - Ajouter les imports nécessaires (`dio.provider.dart`, `dio.download.repository.dart`).

- [x] 4.2 Lancer `dart run build_runner build --delete-conflicting-outputs` pour régénérer `download.repository_provider.g.dart`.

## 5. Vérification

- [x] 5.1 `flutter analyze` vert.

- [x] 5.2 `flutter test` vert. Suite complète, en particulier :
  - `test/infrastructure/downloads/http_download_stream_test.dart` (nouveau)
  - `test/infrastructure/downloads/dio.download.repository_test.dart` (nouveau)
  - `test/infrastructure/downloads/in_memory_download_repository_test.dart` (existant — non-régression après refactor vers le helper)
  - `test/core/application/usecases/start_movie_download_usecase_test.dart`, `cancel_movie_download_usecase_test.dart`, `find_movie_download_usecase_test.dart`, `delete_movie_download_usecase_test.dart` (existants — non-régression, le contrat Domain n'a pas bougé)
  - `test/ui/pages/player/widgets/player_download_gate_test.dart` (existant — non-régression)
  - `test/core/domain/model/movie_download_test.dart` (existant — non-régression)
  - `test/infrastructure/auth/dio.auth.repository_test.dart`, `test/infrastructure/catalog/dio.catalog.repository_test.dart`, `test/infrastructure/profile_management/dio.profile_management.repository_test.dart` (existants — non-régression, leur `Dio` n'est pas affecté)

- [ ] 5.3 Lancement manuel **mode in-memory** (sans flag) : `flutter run`. Vérifier que :
  - Le flow OTP → sélection profil → homepage → ouverture détail → `"Lire"` lance Big Buck Bunny depuis archive.org (aucune requête vers un backend Kidflix).
  - Le `PlayerDownloadGate` affiche le skeleton, puis lance la lecture quand le seuil 2 MiB / 3% est franchi.
  - Le `.mp4.partial` apparaît dans `${documents}/downloads/`, puis devient `.mp4` à la fin.
  - Tuer l'app pendant le download → relancer → `findByMovieId` détecte le `.partial` (status `cancelled`) → bouton `"Lire"` redéclenche un `download` qui resume via `Range`.
  - Tuer l'app après complétion → relancer → `findByMovieId` détecte le `.mp4` final → la lecture démarre instantanément.

- [ ] 5.4 Lancement manuel **mode HTTP** contre un backend local qui implémente `GET /movies/{movie_id}/download` :
  - iOS Simulator : `flutter run --dart-define=API_BASE_URL=http://localhost:8080`
  - Android emulator : `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`
  - Login OTP, sélection profil, ouverture d'un film.
  - **Cas nominal** : vérifier dans les logs / DevTools Network qu'une requête `GET http://localhost:8080/movies/{id}/download` est émise avec headers `Authorization: Bearer ...`, `X-Device-Id: ...`, et **sans** `Range` au premier appel.
  - **Reprise** : tuer pendant le download → relancer → vérifier que le second appel envoie `Range: bytes=N-` où N est la taille du `.partial`.
  - **Erreur 403** : se connecter avec un profil dont la catégorie d'âge interdit le film (modifier la catégorie de profil ou le film côté backend) → vérifier que le download finit en `failed` ; l'UI affiche l'erreur dans le `PlayerDownloadGate`.
  - **Erreur 404** : utiliser un movieId inexistant (manipulation manuelle du router ou patch du catalog) → `failed`.
  - **Coupure réseau** : pendant le download, désactiver le wifi → vérifier que le download finit en `failed` ; le `.partial` est préservé sur disque pour une éventuelle reprise.
  - **Cancel** : démarrer un download long, fermer la `PlayerPage` rapidement → vérifier que le `.partial` est préservé sur disque ; aucun appel HTTP DELETE émis.
  - **Reuse cross-mode** : télécharger un film en mode in-memory (Big Buck Bunny, renommé en `${movieId}.mp4`), puis relancer en mode HTTP → `findByMovieId` détecte le `.mp4` existant, la lecture démarre sans appel HTTP. (Comportement souhaitable : pas de re-download forcé. C'est un side-effect du contrat `findByMovieId` filesystem-only — acceptable.)

- [x] 5.5 `openspec validate add-http-download-repository --strict` vert.
