## 1. Dépendances

- [x] 1.1 Ajouter au `pubspec.yaml` sous `dependencies` :
  - [x] `media_kit` (dernière version stable)
  - [x] `media_kit_video`
  - [x] `media_kit_libs_video` (bundle de libs natives multi-plateformes)
  - [x] `dio` (download HTTP avec streaming response + Range)
  - [x] `path_provider` (application documents directory)
  - [x] `wakelock_plus` (empêcher la veille pendant la lecture)
- [x] 1.2 Lancer `flutter pub get` et vérifier que `flutter analyze` reste vert
- [x] 1.3 Vérifier les notes d'installation natives de `media_kit` : Info.plist iOS (si applicable), aucune action nécessaire macOS/Android/Linux d'après la doc actuelle

## 2. Domaine — downloads

- [x] 2.1 Créer `lib/core/domain/model/movie_download.dart` :
  - classe immuable `MovieDownload` avec `movieId`, `status` (enum `DownloadStatus`), `bytesReceived`, `bytesTotal` (nullable), `localPath` (nullable), `errorMessage` (nullable), `updatedAt`
  - `DownloadStatus` enum : `notStarted`, `downloading`, `readyToPlay`, `complete`, `failed`, `cancelled`
  - `operator ==` et `hashCode` sur `(movieId, status, bytesReceived, updatedAt)`
  - getter utilitaire `bool get isPlayable => status == readyToPlay || status == complete`
  - doc-comment clair sur la progression des statuts
- [x] 2.2 Créer `lib/core/domain/services/download.repository.dart` :
  - `abstract interface class DownloadRepository`
  - méthodes : `findByMovieId`, `download` (retourne `Stream<MovieDownload>`), `cancel`, `delete`
  - doc-comment par méthode avec les invariants du spec `downloads`

## 3. Domaine — watch progress

- [x] 3.1 Créer `lib/core/domain/model/watch_progress.dart` :
  - classe immuable `WatchProgress` avec `profileId`, `movieId`, `positionSeconds`, `completed`, `updatedAt`
  - `operator ==` et `hashCode` sur `(profileId, movieId)` uniquement
  - doc-comment sur la sémantique d'égalité et l'absence intentionnelle de `deviceId`
- [x] 3.2 Créer `lib/core/domain/services/watch_progress.repository.dart` :
  - `abstract interface class WatchProgressRepository`
  - méthodes : `findFor({required profileId, required movieId})`, `save(WatchProgress)`, `listForProfile(String profileId)`
  - doc-comment avec upsert semantics

## 4. Application — DTOs

- [x] 4.1 Créer `lib/core/application/dtos/movie_download.dto.dart` :
  - classe `MovieDownloadDto` miroir du Domain, avec `DownloadStatusDto` enum
  - factory `MovieDownloadDto.fromDomain(MovieDownload)`
  - getters utilitaires `isPlayable`, `progressFraction` (nullable si total inconnu)
- [x] 4.2 Créer `lib/core/application/dtos/watch_progress.dto.dart` :
  - classe `WatchProgressDto`
  - factory `WatchProgressDto.fromDomain(WatchProgress)`
  - méthode `WatchProgress toDomain()` (utile pour les saves depuis l'UI)

## 5. Application — usecases downloads

- [x] 5.1 Créer `lib/core/application/usecases/start_movie_download.usecase.dart` :
  - dépend de `DownloadRepository`
  - `Stream<MovieDownloadDto> execute(String movieId)` — map les évents Domain en DTO
- [x] 5.2 Créer `lib/core/application/usecases/find_movie_download.usecase.dart` :
  - `Future<MovieDownloadDto?> execute(String movieId)`
- [x] 5.3 Créer `lib/core/application/usecases/cancel_movie_download.usecase.dart` :
  - `Future<void> execute(String movieId)`
- [x] 5.4 Créer `lib/core/application/usecases/delete_movie_download.usecase.dart` :
  - `Future<void> execute(String movieId)`

## 6. Application — usecases watch progress

- [x] 6.1 Créer `lib/core/application/usecases/get_watch_progress.usecase.dart` :
  - `Future<WatchProgressDto?> execute({required String profileId, required String movieId})`
- [x] 6.2 Créer `lib/core/application/usecases/save_watch_progress.usecase.dart` :
  - `Future<void> execute({required String profileId, required String movieId, required int positionSeconds, required bool completed})` — instancie le Domain `WatchProgress` avec `updatedAt: DateTime.now()` en interne

## 7. Infrastructure — InMemoryDownloadRepository

- [x] 7.1 Créer `lib/infrastructure/downloads/in_memory.download.repository.dart` :
  - constante publique `stubUrl = 'https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4'` avec commentaire "MVP: URL stub unique pour tous les films, remplacée par l'endpoint backend en phase 2". Durée ~10 min (nécessaire pour tester resume / 90%). Redirect 302 suivi automatiquement par dio.
  - champ privé `Map<String, _ActiveDownload>` pour la dédup par `movieId`
  - injection de `dio.Dio` et chemin de base via `path_provider` (lazy, caché)
  - méthode privée `_buildPath(String movieId, {required bool partial})` retournant `${documents}/downloads/${movieId}.mp4[.partial]`
  - méthode privée `_ensureDownloadsDir()` qui crée le dossier `downloads/` si absent
  - impl `findByMovieId` : check si `${movieId}.mp4` existe → `complete`, sinon si `${movieId}.mp4.partial` existe → `failed` (ou `cancelled`) avec taille du fichier, sinon si une entry est active → reflète son état courant, sinon `null`
  - impl `download` : dédup sur `movieId`, si déjà complete renvoie un `Stream.value(...)` closed, sinon lance un `StreamController.broadcast`, ouvre `.partial` en append si existe (sinon créé), envoie la requête `dio.get` avec `ResponseType.stream` et header `Range: bytes=X-` si reprise, pipe les chunks dans le fichier, émet des `MovieDownload` aux règles du spec (throttling 4 Hz, threshold 2 MiB + 3%, status transitions), rename `.partial` → `.mp4` et émet `complete` en fin
  - impl `cancel` : trigger l'abort du token dio + émet `cancelled` + close stream, préserve le `.partial`
  - impl `delete` : cancel si actif, supprime `.mp4` et `.mp4.partial` s'ils existent, nettoie la map
  - gestion d'erreur : `DioException` → émet `failed` avec `errorMessage` = message exception
- [x] 7.2 Extraire la logique de throttling dans une petite classe interne `_ThrottledEmitter` (ou `package:rxdart` — éviter, pas envie d'une dep de plus) : tick à 250 ms, drop les byte-updates intermédiaires, laisse passer les status-changes immédiatement
  - (Finalement inline dans le loop avec `lastThrottledEmit` + diff 250ms — simple et suffisant, pas de classe dédiée nécessaire.)

## 8. Infrastructure — InMemoryWatchProgressRepository

- [x] 8.1 Créer `lib/infrastructure/watch_progress/in_memory.watch_progress.repository.dart` :
  - champ `Map<String, WatchProgress>` avec clé `"${profileId}|${movieId}"` (string composite simple)
  - impl `findFor` : lookup par clé composite
  - impl `save` : upsert
  - impl `listForProfile` : filter entries par `profileId`

## 9. Infrastructure — providers

- [x] 9.1 Créer `lib/infrastructure/providers/download.repository_provider.dart` avec `@Riverpod(keepAlive: true)` retournant l'`InMemoryDownloadRepository` (instance unique pour la durée de vie de l'app, dio instancié une seule fois)
- [x] 9.2 Créer `lib/infrastructure/providers/download.usecases_provider.dart` :
  - provider pour chaque usecase `StartMovieDownloadUseCase`, `FindMovieDownloadUseCase`, `CancelMovieDownloadUseCase`, `DeleteMovieDownloadUseCase`
  - éventuellement un `StreamProvider.family<MovieDownloadDto, String>` nommé `movieDownloadStreamProvider(movieId)` qui compose `StartMovieDownloadUseCase.execute` pour simplifier l'usage côté UI
- [x] 9.3 Créer `lib/infrastructure/providers/watch_progress.repository_provider.dart` avec `@Riverpod(keepAlive: true)` retournant l'`InMemoryWatchProgressRepository`
- [x] 9.4 Créer `lib/infrastructure/providers/watch_progress.usecases_provider.dart` :
  - `getWatchProgressUseCaseProvider`
  - `saveWatchProgressUseCaseProvider`
- [x] 9.5 Lancer `dart run build_runner build --delete-conflicting-outputs` pour régénérer les `.g.dart`

## 10. UI — router + modale

- [x] 10.1 Modifier `lib/ui/router/app_router.dart` :
  - ajouter `static const player = '/player/:movieId'` dans `AppRoutes`
  - ajouter `GoRoute(path: AppRoutes.player, builder: (_, s) => PlayerPage(movieId: s.pathParameters['movieId']!))`
  - vérifier que la redirection liée à `SessionState` laisse passer `/player/*` pour les profils sélectionnés (le redirect actuel compare `current == target` ; ajuster pour autoriser les sous-routes légitimes d'un `ProfileSelected`, comme `_isManageSubRoute` le fait pour `ManagingProfiles`)
- [x] 10.2 Modifier `lib/ui/pages/home/widgets/movie_detail_modal.widget.dart` :
  - `_PlayButton` n'est plus const, reçoit l'ID du film en paramètre (propager depuis `MovieDetailContent`)
  - `onPressed: () { Navigator.of(context).pop(); context.go('/player/$movieId'); }` (dismiss modale puis navigate)
  - retirer le `Tooltip` `"Lecture bientôt disponible"`
  - adapter `MovieDetailContent` pour passer `movie.id` au `_PlayButton`

## 11. UI — PlayerPage

- [x] 11.1 Créer `lib/ui/pages/player/player.page.dart` :
  - `class PlayerPage extends ConsumerStatefulWidget` avec `final String movieId` en param
  - state avec :
    - `Player? _player`, `VideoController? _videoController` (media_kit)
    - `StreamSubscription<MovieDownloadDto>? _downloadSub`
    - `MovieDownloadDto? _lastDownload`
    - `Timer? _periodicSaveTimer`
    - `Timer? _controlsHideTimer`
    - `bool _controlsVisible`
    - `Duration? _duration`, `Duration _position`, `bool _playing`, `bool _completedEmitted`
  - `initState` : bootstrap du flow (cf. spec `video-playback` §"Player page orchestrates download-then-play")
  - orientations/wakelock selon plateforme et état playback
  - `dispose` : save progress final, dispose player, cancel timers/subscriptions, restore orientations/wakelock
- [x] 11.2 Méthodes privées :
  - `_bootstrap()` : async, appelle `FindMovieDownloadUseCase`, branche soit sur `_openPlayer(localPath)` direct soit sur `_observeDownload(movieId)`
  - `_observeDownload(movieId)` : écoute le stream, met à jour `_lastDownload`, déclenche `_onReadyToPlay(localPath)` à la 1re occurrence de `readyToPlay`
  - `_onReadyToPlay(localPath)` : appelle `_maybeShowResumeDialog()` puis `_openPlayer(localPath, initialPosition)`
  - `_maybeShowResumeDialog()` : get progress via usecase, si conditions réunies montre `ResumeDialog`, retourne la position initiale
  - `_openPlayer(localPath, initialPosition)` : instancie `Player` + `VideoController`, ouvre, seek, play, abonne aux évents du player pour mettre à jour `_position`, `_duration`, `_playing`, et vérifier le seuil de complétion
  - `_startPeriodicSave()` / `_stopPeriodicSave()`
  - `_onTick()` : toutes les 10s, si `_playing`, save progress
  - `_checkCompletion()` : si `position/duration > 0.9` et pas encore marqué, save avec `completed = true` et mémorise
  - `_toggleControls()` pour le auto-hide
- [x] 11.3 Build method :
  - `WillPopScope` ou `PopScope` pour intercepter back et s'assurer du save avant pop
  - corps selon état :
    - `_lastDownload == null && _player == null` : loading spinner
    - `_lastDownload?.status == downloading` : `PlayerDownloadGate`
    - `_lastDownload?.status == failed` ou `cancelled` (avant ready) : `PlayerErrorState`
    - player actif : `Stack` avec `Video(controller: _videoController)` + overlay controls conditionnel
  - `GestureDetector` sur la vidéo pour `_toggleControls()`

## 12. UI — widgets player

- [x] 12.1 Créer `lib/ui/pages/player/widgets/player_download_gate.widget.dart` :
  - reçoit `MovieDownloadDto` (ou `{bytesReceived, bytesTotal}`) + `movieTitle` + `onCancel`
  - rendu : titre, progress indicator (linear si total connu, circular sinon), caption formaté MB, bouton Annuler
  - formatage MB : 1 décimale, utiliser une petite fonction pure `formatBytesMB(int)` dans le fichier
- [~] 12.2 ~~Créer `lib/ui/pages/player/widgets/player_controls.widget.dart`~~ **Retiré** : la `PlayerPage` utilise désormais `MaterialVideoControls` de `media_kit_video`, configuré via `MaterialVideoControlsTheme` (top/bottom button bars custom). Cf. décision #10 du design.md.
- [~] 12.3 ~~Créer `lib/ui/pages/player/widgets/player_seek_bar.widget.dart`~~ **Retiré** même raison — la seek bar est celle de media_kit (avec son propre indicateur de buffer mpv).
- [x] 12.4 Créer `lib/ui/pages/player/widgets/resume_dialog.widget.dart` :
  - fonction `Future<ResumeChoice?> showResumeDialog(BuildContext, Duration position)`
  - `enum ResumeChoice { resume, restart }`
  - dialog non-dismissible (`barrierDismissible: false`, `WillPopScope(onWillPop: () async => false)`)
  - titre `"Reprendre la lecture ?"`, actions `"Reprendre à ${formatDurationHuman(position)}"` et `"Recommencer"`

## 13. UI — widgets player (error state)

- [x] 13.1 Dans `player.page.dart` ou widget dédié `player_error_state.widget.dart` :
  - fonction / widget `PlayerErrorState({required DownloadStatusDto status, String? errorMessage, VoidCallback onRetry, VoidCallback onBack})`
  - message selon `status` (failed → `"Impossible de télécharger le film."`, cancelled → `"Téléchargement annulé."`)
  - boutons `Réessayer` (primary) et `Retour` (secondary)

## 14. Tests — domaine

- [x] 14.1 Créer `test/core/domain/model/movie_download_test.dart` :
  - equality : deux `MovieDownload` avec mêmes `(movieId, status, bytesReceived, updatedAt)` sont égaux
  - `isPlayable` retourne `true` pour `readyToPlay` et `complete`, `false` pour le reste
  - construction avec tous les statuts
- [x] 14.2 Créer `test/core/domain/model/watch_progress_test.dart` :
  - equality par `(profileId, movieId)` uniquement
  - deux instances avec positions différentes pour même paire sont `==`
  - `hashCode` cohérent

## 15. Tests — application

- [x] 15.1 Créer `test/core/application/usecases/start_movie_download_usecase_test.dart` :
  - fake repo émet une séquence `downloading (0.5 MB)` → `downloading (2.5 MB)` → `readyToPlay` → `complete`
  - vérifier que le usecase mappe chaque event en `MovieDownloadDto` dans le même ordre
- [x] 15.2 Créer `test/core/application/usecases/find_movie_download_usecase_test.dart` :
  - repo retourne `null` / `complete` / `downloading` → usecase retourne `null` / dto complet / dto downloading
- [x] 15.3 Créer `test/core/application/usecases/cancel_movie_download_usecase_test.dart` :
  - appel au usecase déclenche `cancel(movieId)` sur le fake repo
- [x] 15.4 Créer `test/core/application/usecases/delete_movie_download_usecase_test.dart` :
  - idem avec `delete`
- [x] 15.5 Créer `test/core/application/usecases/get_watch_progress_usecase_test.dart` :
  - repo retourne `null` → usecase retourne `null`
  - repo retourne un `WatchProgress` → usecase retourne le DTO correspondant
- [x] 15.6 Créer `test/core/application/usecases/save_watch_progress_usecase_test.dart` :
  - usecase appelle `save` sur le repo avec un `WatchProgress` construit à partir des params
  - `updatedAt` est proche de `DateTime.now()` au moment de l'appel (±1s)

## 16. Tests — infrastructure (downloads)

- [x] 16.1 Créer `test/infrastructure/downloads/in_memory_download_repository_test.dart` avec un `HttpClientAdapter` custom (`_FakeAdapter`) qui simule les réponses HTTP :
  - happy path `downloading → readyToPlay → complete` (seuil 2 MiB vérifié)
  - `localPath` bascule de `.partial` vers `.mp4` au `complete`, `.partial` supprimé
  - `findByMovieId` après `complete` → `status == complete` avec le bon path
  - `findByMovieId` sur `.partial` seul → `status == cancelled` avec `bytesReceived` = taille fichier
  - `delete` sur movieId inconnu est idempotent et sans exception
  - `delete` supprime `.mp4` et `.partial` sur disque
  - dédup : deux appels concurrents à `download(sameId)` → `adapter.requestCount == 1`, les deux streams reçoivent les mêmes événements
  - reprise : `.partial` 1 MiB pré-existant → la requête dio inclut `range: bytes=1048576-`
  - **Non testé** : throttling exact (difficile à rendre déterministe sans fake timer), cancel pendant un download en vol (le Stream-based adapter émet tout d'un coup en test, rend cancel non significatif ici — couvert manuellement en §20). Le comportement est compact dans le code et vérifié par inspection.
- [x] 16.2 Utiliser `Directory.systemTemp.createTempSync()` par test et cleanup via `tearDown`

## 17. Tests — infrastructure (watch progress + providers)

- [x] 17.1 Créer `test/infrastructure/watch_progress/in_memory_watch_progress_repository_test.dart` :
  - save puis findFor retourne l'entrée
  - second save écrase le premier pour la même paire
  - findFor sur une paire inconnue retourne null
  - listForProfile filtre correctement (n'inclut pas un autre profil)
  - listForProfile vide retourne `[]`
- [~] 17.2 Tests de providers (`download_providers_test.dart`, `watch_progress_providers_test.dart`) non ajoutés : les providers actuels sont de simples wrappers `@Riverpod(keepAlive: true)` sans logique métier testable de manière significative au-delà de ce que les tests repo + usecase couvrent déjà. L'usage concret est validé par `flutter analyze` (typage correct) et les tests end-to-end manuels §20.
- [~] 17.3 Idem — mutualisé avec 17.2

## 18. Tests — UI (widgets isolés)

- [x] 18.1 Créer `test/ui/pages/player/widgets/player_download_gate_test.dart` :
  - rendu avec bytesTotal connu : progress linéaire, caption `"X.X MB / Y.Y MB"`
  - rendu avec bytesTotal null : progress linéaire indéterminée, caption `"X.X MB"` seule (ajustement de design : même widget `LinearProgressIndicator`, juste sans value)
  - bouton Annuler appelle le callback passé
  - tests dédiés pour `formatBytesMB`
- [~] 18.2 ~~`player_seek_bar_test.dart`~~ **Retiré** (widget supprimé au profit de `MaterialVideoControls`).
- [x] 18.3 Créer `test/ui/pages/player/widgets/resume_dialog_test.dart` :
  - dialog rendu avec `position = 30min` affiche `"Reprendre à 30 min"` et `"Recommencer"`
  - tap sur "Reprendre" résout avec `ResumeChoice.resume`
  - tap sur "Recommencer" résout avec `ResumeChoice.restart`
- [~] 18.4 ~~`player_controls_test.dart`~~ **Retiré** (widget supprimé au profit de `MaterialVideoControls`).
- [x] 18.5 Créer `test/ui/pages/player/widgets/player_error_state_test.dart` (bonus) :
  - message "failed" / "cancelled" selon status
  - callbacks Réessayer / Retour

## 19. Tests — UI (PlayerPage integration)

- [~] 19.1 Test d'intégration `PlayerPage` non écrit : le seam `PlayerEngineFactory` est en place (permettrait l'injection d'un fake), mais écrire un test qui orchestre `ProviderScope.overrides` + fakes pour tous les usecases + navigation go_router + timers demande ~200 lignes de setup pour des assertions dupliquées avec les tests widgets isolés (§18) + tests repo/usecase. Le flow sera validé en §20.
- [x] 19.2 Mettre à jour `test/ui/pages/home/widgets/movie_detail_modal_test.dart` :
  - changement : `"Play button is disabled"` → `"Play button is enabled"` avec `expect(button.onPressed, isNotNull)` (couvrir l'inversion du comportement). Le test de navigation effective demanderait un router mock et a été omis — couvert en §20.

## 20. Vérification manuelle

- [ ] 20.1 `flutter run -d macos` : sélectionner un profil, ouvrir une modale, taper "Lire" → vérifier que la download gate apparaît, que la progression avance, que la lecture démarre après ~quelques secondes de buffer
- [ ] 20.2 Pendant la lecture, vérifier que les contrôles s'affichent au tap et se masquent après 3s
- [ ] 20.3 Fermer le player à mi-parcours (close button), rouvrir le même film : vérifier que le dialog resume apparaît avec la bonne position, et que "Reprendre" reprend à la bonne position
- [ ] 20.4 Rouvrir le même film, choisir "Recommencer" : la lecture démarre à 0 ; vérifier que la progression est écrasée au save suivant
- [ ] 20.5 Laisser la lecture passer 90% : vérifier qu'un `completed = true` est sauvegardé (pas de dialog de resume à la réouverture)
- [ ] 20.6 Tenter de seek en avant au-delà du buffered pendant un download : vérifier que le scrubber est clampé
- [ ] 20.7 Annuler un download pendant la gate : vérifier le retour au home et la présence du `.partial` sur disque (via Finder ou console)
- [ ] 20.8 Rouvrir le même film après annulation : vérifier que le download reprend depuis le `.partial` (le premier event de progress reflète déjà les bytes du `.partial`)
- [ ] 20.9 `flutter run -d <device-ios>` ou android-simulator : vérifier que l'écran passe en landscape, que la system UI est masquée, que le wakelock fonctionne (screen reste allumé pendant la lecture)
- [ ] 20.10 Simuler une coupure réseau au milieu du download (ex: désactiver le wifi) : vérifier le passage en `failed` et l'affichage de l'error state, puis le Retry

## 21. Qualité & documentation

- [x] 21.1 `flutter analyze` sans warning
- [x] 21.2 `flutter test` tous verts (165 tests)
- [x] 21.3 Mettre à jour le `README.md` :
  - nouvelle section "Lecture vidéo" décrivant le flow download → lecture → progression, la lib `media_kit`, l'URL stub unique, la perte de progression au redémarrage (InMemory)
  - mention que le kid lock reste à faire
- [x] 21.4 Vérifier que `openspec validate add-video-playback-and-downloads --strict` passe
