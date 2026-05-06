## 1. Domain — `DownloadKind`, `DownloadEntry`, kind getter sur snapshots

- [x] 1.1 Créer `lib/core/domain/model/download_kind.dart` avec `enum DownloadKind { cache, download }`. Ajouter `String get jsonValue` (lowercase variant name) et `static DownloadKind fromJson(String)` tolérant aux valeurs inconnues (default `cache`).
- [x] 1.2 Créer `test/core/domain/model/download_kind_test.dart` : sérialisation aller/retour, default sur valeur inconnue, default `cache`.
- [x] 1.3 Modifier `lib/core/domain/model/movie_download.dart` : ajouter `final DownloadKind kind;` (default `DownloadKind.cache`), passer dans le constructeur, exposer en getter. Vérifier que `==` et `hashCode` n'incluent **pas** `kind` (la sémantique est inchangée).
- [x] 1.4 Idem dans `lib/core/domain/model/episode_download.dart`.
- [x] 1.5 Mettre à jour les tests existants (`movie_download_test.dart`, `episode_download_test.dart`) pour vérifier que deux snapshots avec des `kind` différents mais le reste identique restent égaux.
- [x] 1.6 Créer `lib/core/domain/model/download_entry.dart` avec la classe `DownloadEntry` (cf. spec download-management). Égalité par `(mediaKind, mediaId)`, `toString` synthétique.
- [x] 1.7 Tester `download_entry_test.dart` : égalité, fallback `"Vidéo inconnue"`, parent series title pour épisodes.

## 2. Domain — interfaces services + record d'inventaire

- [x] 2.1 Créer `lib/core/domain/model/download_inventory_record.dart` avec la classe (mediaId, isEpisode, bytesOnDisk, kind, completedAt, lastPlayedAt, triggeredByProfileId).
- [x] 2.2 Étendre `lib/core/domain/services/download.repository.dart` : ajouter `listAll`, `totalBytesOnDisk`, `setMovieKind`, `setEpisodeKind`, `markPlayed`. Documenter chaque méthode (default `cache` si manifest absent, idempotence, etc.).
- [x] 2.3 Créer `lib/core/domain/services/download_cleanup.service.dart` avec l'interface `DownloadCleanupService.runCacheCleanup({olderThan, now})`.
- [x] 2.4 Créer `lib/core/domain/services/device_storage_probe.dart` avec l'interface `DeviceStorageProbe.appDownloadsBytes()` + `deviceFreeBytes()` (nullable).

## 3. Infrastructure — `DownloadManifestStore`

- [x] 3.1 Ajouter la dépendance `synchronized: ^3.x` dans `pubspec.yaml`. Lancer `flutter pub get`.
- [x] 3.2 Créer `lib/infrastructure/downloads/download_manifest_entry.dart` : value object `DownloadManifestEntry` (kind, completedAt, lastPlayedAt, triggeredByProfileId) + `toJson` / `fromJson` tolérant aux champs inconnus.
- [x] 3.3 Créer `lib/infrastructure/downloads/manifest_store.dart` : `DownloadManifestStore` interface + `JsonFileDownloadManifestStore` impl. Lazy-load au premier accès, `synchronized.Lock` pour les writes, write-then-rename atomique (`manifest.json.tmp` → `manifest.json`).
- [x] 3.4 Implémenter `findFor`, `upsert`, `remove`, `listAll` sur le store. Construire les clés `"movies/<id>"` / `"episodes/<id>"` via un helper privé.
- [x] 3.5 Gérer le cas manifest manquant (lazy read renvoie `{}`). Gérer le cas malformé (warning log, comportement = vide, prochain write réinitialise le fichier).
- [x] 3.6 Tester `manifest_store_test.dart` : lecture vide, write+read round-trip, format dégradable (manifest absent), write atomique (vérifier que `.tmp` est bien renommé), idempotence des opérations.
- [x] 3.7 Tester la résistance au manifest malformé : créer un fichier non-JSON, vérifier que la lecture renvoie vide + warning, vérifier que le prochain `upsert` réécrit un manifest valide.
- [x] 3.8 Créer un provider Riverpod `downloadManifestStoreProvider` (`@Riverpod(keepAlive: true)`) qui instancie la dépendance unique pour toute l'app. Test override mécanisme standard.

## 4. Infrastructure — extension des `DownloadRepository` impl

- [x] 4.1 Modifier `InMemoryDownloadRepository` pour recevoir le `DownloadManifestStore` via constructeur. Initialiser le manifest provider dans `download_repository_provider.dart` en lui passant le store.
- [x] 4.2 Implémenter `listAll()` sur `InMemoryDownloadRepository` : scanner le `downloadsDir/movies/` et `/episodes/` (`.mp4` + `.partial`), agréger les tailles par id, croiser avec le store.
- [x] 4.3 Implémenter `totalBytesOnDisk()` (somme directe sur les fichiers, pas via `listAll`).
- [x] 4.4 Implémenter `setMovieKind` et `setEpisodeKind` : lecture, mute du field `kind`, upsert. Default `lastPlayedAt = file.lastModified` à la création.
- [x] 4.5 Implémenter `markPlayed` : upsert `lastPlayedAt = DateTime.now()`, créé manifest entry si absent (kind par défaut cache).
- [x] 4.6 Modifier le helper interne pour que les snapshots émis par `downloadMovie/Episode` portent le `kind` lu au début de session. Conserver `==` insensible au `kind`.
- [x] 4.7 Au moment d'un `complete`, écrire `completedAt = DateTime.now()` dans le manifest (en plus du rename `.partial` → `.mp4`). `kind` non modifié (préserver la valeur courante : cache si jamais marqué, download si déjà promu).
- [x] 4.8 Modifier `deleteMovie/Episode` pour aussi supprimer l'entrée manifest correspondante (atomicité dégradable : si l'unlink fichier réussit mais que le manifest fail, le manifest sera vu comme stale au prochain `listAll` qui re-purgera l'entry).
- [x] 4.9 Idem 4.1–4.8 pour `DioDownloadRepository`. Mêmes signatures, comportement identique. Les nouvelles méthodes n'émettent aucune requête HTTP.
- [x] 4.10 Tester `in_memory_download_repository_test.dart` (existant + nouveaux scénarios) : `listAll`, `totalBytesOnDisk`, `setMovieKind`, `markPlayed`. Vérifier idempotence et dégradabilité (manifest absent).
- [x] 4.11 Idem `dio_download_repository_test.dart` : nouveaux scénarios sans réseau (filesystem only).
- [x] 4.12 Vérifier l'isomorphisme in-memory ↔ HTTP : un test paramétré qui vérifie que les deux impls renvoient la même `DownloadInventoryRecord` pour le même setup disk + manifest.

## 5. Infrastructure — `DownloadCleanupService` + `DeviceStorageProbe`

- [x] 5.1 Créer `lib/infrastructure/downloads/download_cleanup_service.dart` : implémentation `RepositoryDownloadCleanupService` qui consomme `DownloadRepository.listAll` + `deleteMovie/Episode`. Boucle séquentielle, log warning sur erreur per-item, retourne le compteur.
- [x] 5.2 Provider Riverpod `downloadCleanupServiceProvider`.
- [x] 5.3 Tester `download_cleanup_service_test.dart` : règle 30j strict, items `kind != cache` ignorés, `lastPlayedAt == null` ignorés (jamais lus), idempotence, continuation après échec per-item.
- [x] 5.4 Choisir le plugin disk-space (D-3 du design : recommandation `disk_space_plus`). Ajouter au `pubspec.yaml`. Vérifier que l'iOS et l'Android compilent.
- [x] 5.5 Créer `lib/infrastructure/downloads/io_device_storage_probe.dart` : implémentation qui délègue à `DownloadRepository.totalBytesOnDisk` pour `appDownloadsBytes`, et au plugin pour `deviceFreeBytes`. Catch tout, retourne `null` proprement.
- [x] 5.6 Provider Riverpod `deviceStorageProbeProvider`.
- [x] 5.7 Tester `io_device_storage_probe_test.dart` : `appDownloadsBytes` correct ; `deviceFreeBytes` renvoie `null` quand le plugin throw (mocker via override).

## 6. Application — use cases d'inventaire et de marquage

- [x] 6.1 Créer `lib/core/application/usecases/list_downloads.usecase.dart` avec la classe + `DownloadInventory(downloads, cache)`. Croisement avec `CatalogRepository.findById` pour les films, `SeriesRepository.findById` pour les épisodes. Fallback `"Vidéo inconnue"` sur lookup failure (catch l'exception, log warning).
- [x] 6.2 Tri par `lastPlayedAt` desc, items `null` en bas (sub-tri par `completedAt` desc puis `mediaId`).
- [x] 6.3 Tester `list_downloads_usecase_test.dart` : partition cache/download, tri, fallback `"Vidéo inconnue"`, croisement épisode → série parente.
- [x] 6.4 Créer `lib/core/application/usecases/mark_as_download.usecase.dart` (thin wrapper sur `setMovieKind/setEpisodeKind`). Idem `mark_as_cache.usecase.dart`.
- [x] 6.5 Tester les deux use cases : idempotence, no-op sur id absent, dispatch isEpisode true/false.
- [x] 6.6 Créer `lib/core/application/usecases/get_storage_summary.usecase.dart` qui compose probe + listAll partition. Parallèle (`Future.wait`).
- [x] 6.7 Tester `get_storage_summary_usecase_test.dart` : aggregation correcte, gestion `null` `deviceFreeBytes`.
- [x] 6.8 Adapter `start_movie_playback.usecase.dart` :
  - lire le profil actif via la session, l'écrire comme `triggeredByProfileId` **uniquement si pas déjà présent dans le manifest** (création initiale).
  - appeler `downloadRepository.markPlayed(mediaId, isEpisode: false)` au moment opportun (après player open ou avant subscribe au stream — choix d'impl).
- [x] 6.9 Idem `start_episode_playback.usecase.dart`.
- [x] 6.10 Mettre à jour les tests existants des deux use cases pour vérifier le bump `markPlayed` et le set initial de `triggeredByProfileId`.

## 7. Application — `DownloadSeasonUseCase` + cleanup boot

- [x] 7.1 Créer `lib/core/application/usecases/download_season.usecase.dart` avec la classe et `DownloadSeasonProgress`. Loop séquentiel par-épisode, marquer chaque épisode `kind=download` à la complétion, abort sur failed/cancelled, skip les épisodes déjà téléchargés (réémission immédiate du `complete`-équivalent + setKind si cache).
- [x] 7.2 Tester `download_season_usecase_test.dart` : 8 épisodes en série, skip d'un épisode déjà download (pas de réseau), promote d'un cache, abort sur failed, cancellation propre.
- [x] 7.3 Créer `lib/core/application/preferences/cache_cleanup_preferences.dart` (interface) + `lib/infrastructure/preferences/shared_prefs_cache_cleanup_preferences.dart` (impl `SharedPreferences`). Clé exacte `download_cleanup.cache_auto_delete_enabled`, default `true`.
- [x] 7.4 Provider Riverpod `cacheCleanupPreferencesProvider`.
- [x] 7.5 Tester `shared_prefs_cache_cleanup_preferences_test.dart` : default `true` quand absent, persistance round-trip.
- [x] 7.6 Créer `lib/core/application/usecases/run_startup_cache_cleanup.usecase.dart`. Lit les prefs, appelle `DownloadCleanupService.runCacheCleanup(olderThan: 30j, now: DateTime.now())` si activé. Log info avec compteur. Best-effort.
- [x] 7.7 Tester `run_startup_cache_cleanup_usecase_test.dart` : enabled (clean exécuté), disabled (skip immédiat), cleanup throws (catch, log, retourne 0).

## 8. Bootstrap — câblage `RunStartupCacheCleanupUseCase` au boot

- [x] 8.1 Localiser le contrôleur de bootstrap actuel (probablement le listener Riverpod sur `currentSessionProvider`). Identifier la transition `Bootstrapping → Authenticated`.
- [x] 8.2 Y ajouter un `unawaited(ref.read(runStartupCacheCleanupUseCaseProvider).execute())`. Mémoriser via un flag `_didRunStartupCleanup` pour ne pas relancer sur une seconde transition `Authenticated`.
- [x] 8.3 Tester `bootstrap_test.dart` (ou équivalent) : transition Anonymous → Authenticated → cleanup invoked once, pas de re-invocation sur logout/relogin pendant la même session app.
- [x] 8.4 Documenter le côté non-bloquant (`unawaited`) dans le code par un commentaire courte ligne.

## 9. UI — page Downloads

- [x] 9.1 Créer `lib/ui/pages/downloads/downloads_page.dart` (squelette, scaffold, AppBar `"Téléchargements"`, body avec `Consumer` sur `listDownloadsUseCaseProvider` + `getStorageSummaryUseCaseProvider`).
- [x] 9.2 Créer `lib/ui/pages/downloads/widgets/storage_summary_header.dart` : carte avec les 3 lignes (occupation app, libre device, compteurs). Format human-readable des bytes (`450 Mo`, `4.2 Go`).
- [x] 9.3 Créer `lib/ui/pages/downloads/widgets/download_entry_tile.dart` : poster, titre, sous-titre (téléchargé par X · vu il y a Yj), taille, expand sur tap → `[Lire] [Garder/Ne plus garder] [Supprimer]`.
- [x] 9.4 Section **Téléchargements** : header `"Téléchargements"` + liste de `DownloadEntryTile`. Empty state `"Rien de téléchargé."`.
- [x] 9.5 Créer `lib/ui/pages/downloads/widgets/cache_section.dart` (collapsable, default collapsed) avec : toggle `"Auto-suppression après 30 jours sans visionnage"` bind sur `cacheCleanupPreferencesProvider`, liste des cache items, bouton bas `"Vider le cache"`.
- [x] 9.6 Confirmation dialog `"Vider le cache ? N items, X Mo seront supprimés."` avant `Vider le cache`. Idem confirmation pour chaque `[Supprimer]` per-item.
- [x] 9.7 Refresh sur action : après chaque mutation (`MarkAs*`, `delete*`), invalidate `listDownloadsUseCaseProvider` et `getStorageSummaryUseCaseProvider`.
- [x] 9.8 Pull-to-refresh affordance sur la page (`RefreshIndicator`).
- [x] 9.9 Tester `downloads_page_test.dart` : empty state, présence des 2 sections, action `Garder` qui invalide les providers, action `Vider le cache` avec confirmation.

## 10. UI — bouton Télécharger sur la modale film

- [x] 10.1 Localiser la modale détail film (probablement `lib/ui/catalog/catalog_item_detail_modal.dart` après `add-series-viewing`). Identifier le `Row` qui contient le bouton `[Lire]`.
- [x] 10.2 Ajouter un `Consumer` qui observe `findForMovie(id)` (ou un provider famille équivalent) et calcule l'état d'affichage (Télécharger / Téléchargé / In-flight).
- [x] 10.3 Implémenter le bouton secondaire selon les 3 états (cf. spec catalog) : `[⬇ Télécharger]` / `[✓ Téléchargé]` / `[⏸ X %]`.
- [x] 10.4 Câbler le tap : appel à un helper `await _gateAndPromote(context, ref, id, isEpisode: false)` qui :
  - Lit la session pour identifier le profil actif.
  - Si kid → `showUnlockPinDialog(context, ref)` (réutilise l'existant kids-lock).
  - Sur success (ou parent), `markAsDownloadUseCase.execute(...)` ; si pas de download in-flight, déclencher aussi `downloadRepositoryProvider.downloadMovie(id).listen(...)` pour démarrer la transmission.
- [x] 10.5 Bottom sheet pour `[✓ Téléchargé]` avec `[Ne plus garder]` + `[Supprimer]` (les deux via le même gate helper).
- [x] 10.6 Tester `movie_detail_modal_download_button_test.dart` : 3 états visuels, gate kid déclenche dialog, parent skip, mutation flips manifest sans interrompre le DL.

## 11. UI — bouton par-épisode et bouton saison

- [x] 11.1 Localiser `lib/ui/catalog/series/episode_card.dart`. Ajouter une icône d'action à droite (`Icons.file_download_outlined` / `_done` / progress overlay selon état).
- [x] 11.2 Câbler le tap via le même helper `_gateAndPromote(context, ref, episodeId, isEpisode: true)`.
- [x] 11.3 Localiser `lib/ui/catalog/series/season_section.dart`. Ajouter un bouton header `[⬇ Télécharger la saison]` avec progression live `"X / N"` quand le download de saison est actif.
- [x] 11.4 Bouton saison désactivé en `[✓ Saison téléchargée]` quand tous les épisodes sont déjà `kind=download`.
- [x] 11.5 Câbler le tap : un seul gate, puis `downloadSeasonUseCase.execute(seriesId, seasonNumber)`. Subscribe au stream pour la progression. Snackbar finale.
- [x] 11.6 Annulation : back button ou affordance dédiée → cancel le `StreamSubscription` (ce qui cascade sur l'épisode in-flight courant).
- [x] 11.7 Tester `episode_card_download_test.dart` et `season_section_download_test.dart` : icônes par état, gate, batch saison séquentiel, cancel propre.

## 12. UI — entrée vers `/downloads` et route gardée

- [x] 12.1 Décider entre les options D-7 (proposal) après inspection du code : long-press photo profil parent, item dans `profile_management`, ou nouvelle page settings dédiée. **Recommandation : extension de `profile_management`**.
- [x] 12.2 Implémenter le point d'entrée choisi : nouvelle ligne `"Téléchargements"` dans la page parent, push vers `/downloads` après PIN gate (réutiliser le challenge existant de `profile_management`).
- [x] 12.3 Ajouter la route `/downloads` dans `lib/ui/router/app_router.dart`. Garder l'accès cohérent avec `profile_management` : si l'entry-point gate déjà avec le PIN, la route en elle-même n'a pas besoin d'un guard supplémentaire (sinon double dialog). Si on choisit un point d'entrée non-gardé, alors la route doit avoir son propre guard.
- [x] 12.4 Tester l'entry-point : tap sur le menu item → PIN dialog → push `/downloads` ; cancel → pas de push.

## 13. Test exercice end-to-end (in-memory)

- [x] 13.1 Sur `flutter run` (mode in-memory) : lancer un film, vérifier que le download tourne en arrière-plan et apparaît en `cache` dans la page manager.
- [x] 13.2 Sur la modale film, presser `[Télécharger]`, valider PIN, vérifier que l'item bascule en `download` dans le manager.
- [x] 13.3 Lancer un download de saison Pingu, vérifier que les épisodes s'enchaînent et apparaissent un par un dans `Téléchargements`.
- [x] 13.4 Désactiver le toggle auto-clean, killer et relancer l'app, vérifier qu'aucun cleanup ne tourne (log absent).
- [x] 13.5 Réactiver, simuler un item cache vieux > 30j (mtime forcé via shell), relancer l'app, vérifier que le log `info` apparaît et que l'item est supprimé.
- [x] 13.6 Supprimer un profil qui avait `triggeredByProfileId` sur un download, vérifier que l'affichage devient `"Téléchargé par profil supprimé"` et que le fichier reste sur disque.
- [x] 13.7 Test promotion mid-vol : lancer la lecture d'un long film, attendre 30 % de download, presser `[Télécharger]` → vérifier que le download n'est pas redémarré (compteur HTTP / log) et que la complétion finit en `kind=download`.

## 14. Vérifications finales et cleanup

- [x] 14.1 Lancer `dart analyze` — zéro warning sur les fichiers nouveaux/modifiés.
- [x] 14.2 Lancer `flutter test` — tous tests passent.
- [x] 14.3 Lancer `openspec validate add-download-management --strict` (si la commande existe), corriger d'éventuels écarts spec/impl.
- [x] 14.4 Vérifier que `lib/infrastructure/downloads/manifest_store.dart` ne logge jamais de PII (profil ids OK, pas de PIN, pas de JWT).
- [x] 14.5 Vérifier que `RunStartupCacheCleanupUseCase` est bien câblé en `unawaited` et qu'aucun await ne bloque la home page.
- [x] 14.6 Smoke test sur HTTP mode (`flutter run --dart-define=API_BASE_URL=http://localhost:8080`) : vérifier que les boutons Télécharger fonctionnent contre le backend réel et que le manager affiche correctement l'inventaire.
