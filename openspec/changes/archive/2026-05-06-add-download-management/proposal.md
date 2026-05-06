## Why

Aujourd'hui, **tout fichier vidéo joué est implicitement téléchargé en
entier** — le player consomme le stream `downloadMovie/Episode` du
`DownloadRepository`, qui écrit progressivement à
`${documents}/downloads/{movies|episodes}/<id>.mp4`. Ce comportement
fait office de cache de lecture, mais :

- Aucune visibilité parent sur ce qui occupe le téléphone (combien
  d'items, combien de Go, lesquels).
- Aucune politique de nettoyage : le disque grossit indéfiniment au
  rythme des visionnages, jusqu'à saturation.
- Aucune intention explicite de **garder** une vidéo offline pour
  longtemps (typique : Tchoupi pour la voiture, Pingu en avion). Le
  parent ne peut pas distinguer "ça c'est du cache, le système peut
  s'en débarrasser" de "ça c'est gardé exprès, n'y touche pas".

Cette change introduit la distinction **cache** (jeté automatiquement
après 30 jours sans relecture) vs **download** (gardé jusqu'à
suppression manuelle), un **bouton "Télécharger" explicite** sur les
pages film/épisode/série, et une **page manager parent** pour
visualiser l'occupation, vider le cache, et supprimer manuellement les
téléchargements.

## What Changes

### Domaine

- **NOUVEAU** `enum DownloadKind { cache, download }` dans
  `lib/core/domain/model/download_kind.dart` (ou co-localisé avec
  `movie_download.dart` — choix d'implémentation). `cache` est la
  valeur par défaut quand un download a été déclenché par le player ;
  `download` est la valeur quand l'intention explicite "Télécharger" a
  été faite.
- **NOUVEAU** `class DownloadEntry` (Domain value object) qui agrège
  un `MovieDownload | EpisodeDownload` complété avec ses metadata
  applicatives (`kind`, `completedAt`, `lastPlayedAt`,
  `triggeredByProfileId`, `bytesOnDisk`). Sert de modèle d'affichage
  pour le manager. Pas exposé en public via le `DownloadRepository`
  bas niveau ; produit par le service de management (cf. application).
- **MODIFIÉ** `MovieDownload` et `EpisodeDownload` gagnent un getter
  `kind` (lu depuis le manifest, default `cache`). Aucun autre champ
  ne change ; les snapshots restent immutables, l'égalité reste basée
  sur le tuple existant `(id, status, bytesReceived, updatedAt)` —
  `kind` ne casse pas l'identité d'un snapshot.

### Repositories (interfaces Domain)

- **MODIFIÉ** `DownloadRepository` (extension, pas de breaking) :
  - `Future<List<DownloadEntry>> listAll()` — énumère tous les items
    présents sur disque (films + épisodes), avec leurs metadata.
    Renvoie une liste vide si rien.
  - `Future<int> totalBytesOnDisk()` — somme des tailles de tous les
    fichiers `.mp4` et `.mp4.partial` sous `${documents}/downloads/`.
  - `Future<void> setMovieKind(String movieId, DownloadKind kind)`
    et `setEpisodeKind(String episodeId, DownloadKind kind)` —
    promotion ou rétrogradation, écrit le manifest.
  - `Future<void> markPlayed({required String mediaId, required
    bool isEpisode})` — bump le `lastPlayedAt`. Appelé par le player
    à l'ouverture (ou à la fermeture, choix d'implémentation).
- **NOUVEAU** `DownloadCleanupService` (Domain service) avec
  `runCacheCleanup({required Duration olderThan, required DateTime
  now})` qui parcourt `listAll()`, filtre les `kind == cache` dont
  `lastPlayedAt < now - olderThan`, et appelle `deleteMovie/Episode`
  sur chacun. Idempotent ; renvoie le nombre d'items nettoyés.
- **NOUVEAU** `DeviceStorageProbe` (Domain service) :
  - `Future<int> appDownloadsBytes()` — délègue à
    `DownloadRepository.totalBytesOnDisk()`.
  - `Future<int?> deviceFreeBytes()` — renvoie l'espace libre sur
    le volume où vit `${documents}`, ou `null` si la plateforme ne
    peut pas le fournir.

### Persistance metadata (manifest)

- **NOUVEAU** sidecar `${documents}/downloads/manifest.json` qui
  porte les metadata applicatives par item (clé `movies/<id>` ou
  `episodes/<id>`) :
  ```jsonc
  {
    "movies/abc": {
      "kind": "download",            // "cache" | "download"
      "completedAt": "2026-04-01T...", // null tant que non complete
      "lastPlayedAt": "2026-05-04T...", // null tant que jamais joué
      "triggeredByProfileId": "marie"  // profil actif au moment du DL
    },
    "episodes/pingu-s01e04": { ... }
  }
  ```
  - Le manifest est **dégradable** : son absence n'empêche aucun
    download de fonctionner. Un item présent sur disque mais absent
    du manifest est traité comme `kind = cache`,
    `triggeredByProfileId = null`, `lastPlayedAt = file.lastModified`,
    `completedAt = null`. Sécurise la migration depuis l'état
    actuel (manifest inexistant au déploiement).
  - Lecture/écriture concurrente protégée par un `Lock` (package
    `synchronized` ou équivalent) — toutes les mutations passent par
    une queue interne au `DownloadManifestStore`.
  - Format JSON brut, single-file. Pas de versioning au MVP — un
    parser tolérant aux champs inconnus suffit pour autoriser des
    extensions futures sans casser les anciens binaires.

### Application services / usecases

- **NOUVEAU** `ListDownloadsUseCase.execute()` : retourne deux listes,
  `downloads: List<DownloadEntry>` (kind=download) et `cache:
  List<DownloadEntry>` (kind=cache), triées par `lastPlayedAt` desc
  (plus récent en haut). Croise avec `CatalogRepository` /
  `SeriesRepository` pour résoudre titre, poster, série parente. Les
  items dont la métadonnée du catalogue est introuvable (film retiré
  serveur-side, etc.) sont quand même listés sous une fallback
  `"Vidéo inconnue"` avec leur taille — le parent doit pouvoir
  nettoyer dans tous les cas.
- **NOUVEAU** `MarkAsDownloadUseCase.execute({required String mediaId,
  required bool isEpisode})` : appelé après validation du PIN parent.
  Flippe `kind` à `download` via le repo.
- **NOUVEAU** `MarkAsCacheUseCase.execute({...})` : flip inverse,
  rétrograde un download en cache (le rendant éligible à l'auto-clean).
- **NOUVEAU** `DownloadSeasonUseCase.execute({required String
  seriesId, required int seasonNumber})` : appelle
  `downloadEpisode(id)` pour chaque épisode de la saison, marque
  chacun `kind=download` à mesure qu'il complète. Téléchargements
  séquentiels (pas en parallèle) pour ne pas saturer le réseau.
- **NOUVEAU** `RunStartupCacheCleanupUseCase.execute()` : invoqué une
  fois au boot de l'app (post-auth, avant la home). Appelle
  `DownloadCleanupService.runCacheCleanup(olderThan: Duration(days:
  30), now: DateTime.now())`. Best-effort (n'empêche pas le boot si
  ça échoue).
- **NOUVEAU** `GetStorageSummaryUseCase.execute()` : retourne
  `{appDownloadsBytes, deviceFreeBytes, downloadsCount, cacheCount}`.
- **MODIFIÉ** `StartMoviePlaybackUseCase` et
  `StartEpisodePlaybackUseCase` :
  - Avant de lancer le download, lisent le profil actif et
    l'écrivent comme `triggeredByProfileId` dans le manifest **si
    l'item n'a pas encore d'entrée de manifest**.
  - Après ouverture du player, appellent `markPlayed(mediaId)` pour
    bump le `lastPlayedAt`.

### Infrastructure

- **NOUVEAU** `lib/infrastructure/downloads/manifest_store.dart` :
  - `DownloadManifestStore` charge le manifest au premier accès
    (lazy), garde un cache mémoire, écrit à chaque mutation.
  - File-locked write via `synchronized.Lock` pour protéger contre
    les writes concurrents.
- **MODIFIÉ** `DioDownloadRepository` et `InMemoryDownloadRepository`
  reçoivent désormais le `DownloadManifestStore` via constructeur,
  exposent `listAll`, `totalBytesOnDisk`, `setMovieKind`,
  `setEpisodeKind`, `markPlayed`. Les implémentations délèguent au
  manifest pour ces nouveaux appels et n'inventent rien d'autre.
- **NOUVEAU** `lib/infrastructure/downloads/disk_space.dart` :
  `IoDeviceStorageProbe implements DeviceStorageProbe` qui utilise
  un plugin platform-specific (candidate : `disk_space_2` ou
  `disk_space_plus`). Implémentation à choisir dans `design.md` D-3.

### UI

- **NOUVEAU** `lib/ui/pages/downloads/downloads_page.dart` :
  - Route `/downloads`, accessible **depuis les settings parent** (en
    sortie de `VerifyManagementPinUseCase`). Pas d'onglet bottom-bar
    dédié (cohérence avec `profile_management`).
  - Header : récap stockage `"Kidflix occupe X · libre sur l'appareil
    : Y · N téléchargements (X1) · M en cache (X2)"`.
  - Section **"Téléchargements"** : liste des `kind=download`, item
    cliquable → expand avec actions `[Lire]` `[Ne plus garder]`
    `[Supprimer]`.
  - Section **"Cache"** (collapsée par défaut) :
    - Toggle `"Auto-suppression (30 jours sans visionnage)"` (ON par
      défaut — la règle vaut tant qu'elle n'est pas désactivée).
    - Liste des `kind=cache`, item → `[Lire]` `[Garder]`
      `[Supprimer]`.
    - Bouton `"Vider le cache"` en bas.
  - Empty state : si rien sur disque, message `"Rien de téléchargé
    pour le moment."`.
- **MODIFIÉ** modale détail film (`catalog_item_detail_modal.dart`,
  branche `Movie`) : ajoute un bouton `[⬇ Télécharger]` à côté du
  `[▶ Lire]` existant. Quand l'item est déjà en `kind=download`, le
  bouton bascule sur `[✓ Téléchargé]` (désactivé visuellement, mais
  ouvre une feuille avec `[Ne plus garder]` `[Supprimer]`).
- **MODIFIÉ** modale détail série (`catalog_item_detail_modal.dart`,
  branche `Series`) : chaque section saison (`season_section.dart`)
  affiche un bouton `[⬇ Télécharger la saison]` à droite du titre de
  saison. Chaque carte épisode (`episode_card.dart`) gagne une icône
  d'action `[⬇]` à droite (équivalent par-épisode).
- **MODIFIÉ** entrée settings parent (point d'entrée actuel TBD,
  `design.md` D-7) : ajoute une ligne `"Téléchargements"` qui pousse
  `/downloads` après validation du PIN.

### Kids-lock gate

- Tous les boutons "Télécharger" affichés en mode profil enfant
  (kid) SHALL ouvrir le **dialog `showUnlockPinDialog` existant**
  (cf. `kids-lock` capability) avant de déclencher
  `MarkAsDownloadUseCase`. La même mécanique de PIN parent est
  réutilisée — pas de nouveau composant.
- Quand le profil actif est le profil principal (parent), le bouton
  agit directement sans challenge.
- L'accès à la **page manager** elle-même est aussi gardé par le PIN
  (entrée via settings parent).

## Capabilities

### New Capabilities

- `download-management` : la page manager (UI), la politique
  d'auto-clean cache (`lastPlayedAt + 30 jours`), le récap stockage
  device, les use cases `ListDownloadsUseCase`, `MarkAsDownloadUseCase`,
  `MarkAsCacheUseCase`, `DownloadSeasonUseCase`,
  `RunStartupCacheCleanupUseCase`, `GetStorageSummaryUseCase`, et le
  `DownloadCleanupService` Domain.

### Modified Capabilities

- `downloads` : ajoute la distinction `DownloadKind { cache, download }`,
  le sidecar `manifest.json` avec metadata applicatives (`kind`,
  `completedAt`, `lastPlayedAt`, `triggeredByProfileId`,
  `cachedTitle`, `cachedPosterUrl`, `cachedParentSeriesTitle`), et
  les méthodes `listAll`, `totalBytesOnDisk`, `setMovieKind`,
  `setEpisodeKind`, `markPlayed`, `cacheMediaMetadata` sur
  `DownloadRepository`. Le comportement existant des fichiers
  `.mp4`/`.partial` reste inchangé ; le manifest est dégradable
  (absent → tout est traité comme `cache`).
- `catalog` : ajoute le bouton `[⬇ Télécharger]` sur la modale film,
  le bouton `[⬇]` par-épisode sur la liste épisodes, et le bouton
  `[⬇ Télécharger la saison]` sur la section saison. Tous les
  boutons côté kid déclenchent le challenge PIN parent avant action.
  Ajoute aussi `CatalogRepository.listCatalogForProfile(profileId)`
  + `AuthInterceptor` qui préserve un `X-Profile-Id` per-call —
  permet au manager d'unioner les vues catalog de chaque profil
  famille (contournement du filtre `age_category` strict sur
  `/catalog`).
- `series-viewing` : ajoute `SeriesRepository.findByIdForProfile(seriesId, profileId)`
  pour permettre au manager de résoudre une série dont
  l'`age_category` excède celle du profil parent (cas d'un épisode
  téléchargé par un kid).

## Impact

- **Code touché (Domain)** :
  - `lib/core/domain/model/download_kind.dart` — NOUVEAU.
  - `lib/core/domain/model/download_entry.dart` — NOUVEAU.
  - `lib/core/domain/model/movie_download.dart` — getter `kind`.
  - `lib/core/domain/model/episode_download.dart` — getter `kind`.
  - `lib/core/domain/services/download.repository.dart` — extension
    avec `listAll`, `totalBytesOnDisk`, `setMovieKind`,
    `setEpisodeKind`, `markPlayed`.
  - `lib/core/domain/services/download_cleanup.service.dart` —
    NOUVEAU.
  - `lib/core/domain/services/device_storage_probe.dart` — NOUVEAU.
- **Code touché (Application)** :
  - `lib/core/application/usecases/list_downloads.usecase.dart` —
    NOUVEAU.
  - `lib/core/application/usecases/mark_as_download.usecase.dart` —
    NOUVEAU.
  - `lib/core/application/usecases/mark_as_cache.usecase.dart` —
    NOUVEAU.
  - `lib/core/application/usecases/download_season.usecase.dart` —
    NOUVEAU.
  - `lib/core/application/usecases/run_startup_cache_cleanup.usecase.dart`
    — NOUVEAU.
  - `lib/core/application/usecases/get_storage_summary.usecase.dart`
    — NOUVEAU.
  - `lib/core/application/usecases/start_movie_playback.usecase.dart`
    — adapté pour écrire `triggeredByProfileId` et bump
    `lastPlayedAt`.
  - `lib/core/application/usecases/start_episode_playback.usecase.dart`
    — adapté idem.
- **Code touché (Infrastructure)** :
  - `lib/infrastructure/downloads/manifest_store.dart` — NOUVEAU.
  - `lib/infrastructure/downloads/disk_space.dart` — NOUVEAU.
  - `lib/infrastructure/downloads/dio.download.repository.dart` —
    consomme `DownloadManifestStore`, implémente les nouvelles
    méthodes.
  - `lib/infrastructure/downloads/in_memory.download.repository.dart`
    — idem.
  - `lib/infrastructure/providers/download.repository_provider.dart`
    — adapte la construction (injecte le manifest store).
  - `lib/infrastructure/providers/download_cleanup_service_provider.dart`
    — NOUVEAU.
  - `lib/infrastructure/providers/device_storage_probe_provider.dart`
    — NOUVEAU.
- **Code touché (UI)** :
  - `lib/ui/pages/downloads/downloads_page.dart` — NOUVEAU.
  - `lib/ui/pages/downloads/widgets/storage_summary_header.dart` —
    NOUVEAU.
  - `lib/ui/pages/downloads/widgets/download_entry_tile.dart` —
    NOUVEAU.
  - `lib/ui/pages/downloads/widgets/cache_section.dart` — NOUVEAU.
  - `lib/ui/catalog/catalog_item_detail_modal.dart` — bouton
    `[Télécharger]` côté `Movie`.
  - `lib/ui/catalog/series/season_section.dart` — bouton
    `[Télécharger la saison]`.
  - `lib/ui/catalog/series/episode_card.dart` — icône `[⬇]`
    par-épisode.
  - Entry-point settings parent — ligne `"Téléchargements"`
    (composant TBD, voir `design.md` D-7).
  - `lib/ui/router/app_router.dart` — route `/downloads` (gated
    PIN).
- **Tests** :
  - `test/core/domain/model/download_kind_test.dart` — sérialisation
    enum.
  - `test/core/domain/services/download_cleanup_service_test.dart` —
    règle 30 jours, idempotence.
  - `test/infrastructure/downloads/manifest_store_test.dart` —
    lecture/écriture concurrente, format dégradable, fallback.
  - `test/core/application/usecases/list_downloads_usecase_test.dart`
    — croisement avec catalogue, fallback "Vidéo inconnue".
  - `test/core/application/usecases/run_startup_cache_cleanup_usecase_test.dart`
    — items éligibles vs non-éligibles.
  - `test/ui/pages/downloads/downloads_page_test.dart` — affichage
    section downloads + cache, actions, kids-lock challenge.
  - `test/ui/catalog/season_section_test.dart` — bouton télécharger
    la saison, séquencement.
- **Dependencies** :
  - `synchronized` (pub.dev) pour la file-lock du manifest.
  - `disk_space_2` ou `disk_space_plus` (pub.dev) pour
    `deviceFreeBytes` — choix dans `design.md` D-3.
- **API.md** : aucune modification — toute la logique est cliente.
- **Backend** : aucun changement requis. Les endpoints existants
  `GET /movies/{id}/download` et `GET /episodes/{id}/download` sont
  consommés tels quels.
- **Breaking changes** :
  - **Aucun côté HTTP / serveur**.
  - **Aucun côté UI utilisateur** : le comportement par défaut (lire
    un film le télécharge automatiquement) est préservé. Seul ajout :
    le bouton "Télécharger" et la page manager.
  - **Côté code Dart** : signature `DownloadRepository` étendue —
    les implémentations existantes doivent ajouter les nouvelles
    méthodes. Aucun renommage des méthodes existantes.
  - **Migration des fichiers existants** : un déploiement sur un
    téléphone qui a déjà des downloads → manifest absent →
    rétro-classification automatique en `kind=cache`. Le parent peut
    ensuite re-promouvoir manuellement via le manager.
- **Hors scope (différé)** :
  - Quota de taille (LRU sur le cache si > N Go). Pour l'instant
    seule la règle temporelle s'applique ; on ajoutera un plafond
    si l'usage révèle des cas pathologiques.
  - Background scheduler (auto-clean en arrière-plan via
    `WorkManager` ou équivalent). Le nettoyage tourne uniquement au
    boot de l'app — suffisant pour une app dont l'usage est
    quotidien.
  - Téléchargement de séries entières en un clic ("Télécharger
    Pingu" → toutes les saisons). Trop d'octets d'un coup pour le
    MVP ; on garde "Télécharger la saison" comme grain max.
  - Notification système quand un download est complet (les
    batchs saison peuvent être longs).
  - Garbage collection de fichiers `.partial` orphelins (download
    cancelled jamais relancé). Suit la même politique d'âge que le
    cache — différé.
  - Affichage par-profil ("vu par Marie / Léo") dans le manager.
    Au MVP on ne montre que `triggeredByProfileId`. Étendre demande
    de croiser avec `WatchProgressRepository.listForProfile` pour
    chaque profil — différé.
  - Réglage configurable de la durée d'auto-clean (autre que 30j).
- **Précautions opérationnelles** :
  - L'auto-clean tourne au boot dans un `unawaited(...)` —
    n'empêche jamais le démarrage. Si la suppression échoue
    (verrou fichier, permission), l'item reste, sera retenté au
    prochain boot.
  - Le manifest n'est jamais réécrit dans son intégralité quand un
    seul item change : on lit, on mute en mémoire, on écrit
    atomiquement (write-then-rename). Pas de risque de perdre tout
    le manifest sur un crash en cours d'écriture.
