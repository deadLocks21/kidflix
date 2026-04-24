## Why

Le bouton « Lire » de la `MovieDetailModal` est aujourd'hui désactivé avec le tooltip *« Lecture bientôt disponible »* — c'est la seule feature qui fait passer Kidflix d'un catalogue statique à une vraie médiathèque. GLOBALVIEW place la lecture vidéo au cœur de la Phase 3, avec trois exigences fortes : (1) lecture 100% locale après téléchargement, (2) reprise de lecture persistée, (3) démarrage de la lecture dès les premiers octets téléchargés pour éviter l'attente. Ce change implémente tout ce pipeline sous la forme qu'il aura à terme : des ports Domain côté catalogue + progression, des implémentations `InMemory*` qui utilisent un vrai téléchargement HTTP vers le système de fichiers local, et une `PlayerPage` basée sur `media_kit`.

Le kid lock (verrouillage natif de l'écran pendant la lecture) est **hors scope** — il fera l'objet d'une capability dédiée ultérieure.

## What Changes

- **Nouvelle capability `downloads`** : modèle `MovieDownload`, contrat `DownloadRepository`, implémentation `InMemoryDownloadRepository` qui fait un **vrai téléchargement HTTP** via `dio` vers `${documents}/downloads/${movieId}.mp4`, depuis une **URL unique en dur** pour tous les films (Big Buck Bunny sur archive.org, ~62 MB, 720p ~10 min, Range-compatible). Expose un `Stream<MovieDownload>` qui émet des statuts `downloading` → `readyToPlay` (dès un seuil de buffer) → `complete`.
- **Nouvelle capability `video-playback`** : modèle `WatchProgress`, contrat `WatchProgressRepository`, implémentation `InMemoryWatchProgressRepository` (Map en RAM), `PlayerPage` sur route dédiée `/player/:movieId`, `media_kit` utilisé directement dans l'UI (pas de port Domain), dialogue « Reprendre à X ? » si progression existe, sauvegarde toutes les 10s, complétion à > 90%, contrôles minimaux (play/pause, seek, fermer), landscape forcé sur mobile + immersive, wakelock actif pendant la lecture.
- **Pattern « play while downloading »** : le player ouvre le fichier local dès que le download émet `readyToPlay` (~3s vidéo bufférisés). L'écriture continue dans le fichier pendant que `media_kit` le lit. Le renommage final `.partial` → `.mp4` n'interrompt pas la lecture.
- **Modification de `catalog`** : retrait du requirement « Play button is visible but disabled in MVP ». Le bouton « Lire » de la modale devient actif et navigue vers `/player/:movieId`. Le reste du contrat `catalog` est inchangé.
- **Nouvelles dépendances pubspec** : `media_kit`, `media_kit_video`, `media_kit_libs_video`, `dio`, `path_provider`, `wakelock_plus`.

## Capabilities

### New Capabilities
- `downloads` : téléchargement d'un film vers le stockage local, suivi de statut en stream, gestion du fichier partiel, threshold de début de lecture, annulation et suppression. Couvre le modèle Domain, le contrat repository, l'implémentation in-memory réelle (HTTP + FS), et les usecases applicatifs consommés par la lecture.
- `video-playback` : lecture d'un film local via `media_kit`, dialogue de reprise, persistance de la progression, contrôles utilisateur, orientation et wakelock. Couvre le modèle Domain `WatchProgress`, le contrat repository, la page player, et l'intégration avec la modale de détails.

### Modified Capabilities
- `catalog` : suppression du requirement « Play button disabled » devenu obsolète. Le bouton navigue désormais vers la `PlayerPage`. Aucune autre modification du contrat.

## Impact

- **Code ajouté** :
  - Domain : `lib/core/domain/model/movie_download.dart`, `lib/core/domain/model/watch_progress.dart`, `lib/core/domain/services/download.repository.dart`, `lib/core/domain/services/watch_progress.repository.dart`.
  - Application : DTOs correspondants, usecases `StartMovieDownload`, `FindMovieDownload`, `CancelMovieDownload`, `DeleteMovieDownload`, `GetWatchProgress`, `SaveWatchProgress`.
  - Infrastructure : `lib/infrastructure/downloads/in_memory.download.repository.dart`, `lib/infrastructure/watch_progress/in_memory.watch_progress.repository.dart`, providers Riverpod générés sous `lib/infrastructure/providers/`.
  - UI : `lib/ui/pages/player/player.page.dart` + widgets (`player_download_gate`, `player_controls`, `player_seek_bar`, `resume_dialog`).
- **Code modifié** :
  - `lib/ui/pages/home/widgets/movie_detail_modal.widget.dart` : bouton `Lire` actif, navigue vers `/player/:movieId`.
  - `lib/ui/router/app_router.dart` : ajout de `AppRoutes.player` et de la `GoRoute` correspondante.
  - `pubspec.yaml` : ajout des nouvelles dépendances.
- **Dépendances nouvelles** : `media_kit`, `media_kit_video`, `media_kit_libs_video` (lecture vidéo multi-plateforme), `dio` (download HTTP avec progress + Range), `path_provider` (chemin docs local), `wakelock_plus` (empêcher la veille pendant la lecture).
- **Non-impacté** : authentification, sélection de profil, gestion des profils, recherche, design system, homepage catalog. La `MovieDetailModal` reste identique à un détail près (bouton actif).
- **Hors scope** (changements ultérieurs) :
  - Kid lock (overlay Flutter + MethodChannel natifs Android `startLockTask` / iOS Accès Guidé).
  - Contrôles avancés : vitesse de lecture, sous-titres, skip ±10s, chapitres, choix qualité.
  - Download manager multi-films : file d'attente, concurrence, retry exponentiel, downloads en arrière-plan (notifications système).
  - Persistance disque de la progression (arrivera quand le backend HTTP remplacera l'`InMemoryWatchProgressRepository`).
  - Alimentation réelle de la row `continueWatching` par les progressions (change séparé, consommera le `WatchProgressRepository` introduit ici).
  - Gestion du stockage local (écran paramètres, purge automatique des films terminés).
  - Lecture en streaming sans download préalable (l'architecture impose le download local même si la lecture démarre sur fichier partiel).
