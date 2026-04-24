## Context

Kidflix applique l'architecture hexagonale (`UI → Application → Domain ← Infrastructure`) avec des providers Riverpod confinés dans `lib/infrastructure/providers/`. Les changes précédents ont posé l'auth, la sélection de profil, la gestion de profil, et la homepage catalog + recherche. Le `CatalogRepository` est implémenté en in-memory avec 12 films stub. Le bouton `Lire` de la modale est câblé mais désactivé, avec un requirement `catalog` explicite qui le documente comme tel.

Trois éléments du contexte cadrent ce change :

1. **Le plan final est connu** ([GLOBALVIEW.md](../../../GLOBALVIEW.md)) : serveur dockerisé en passe-plat kDrive, fichiers MP4 Web-Optimized (moov au début), API REST avec `GET /download/:movie_id`, `GET /progress/:movie_id`, `POST /progress/:movie_id`. La librairie vidéo est `media_kit` (multi-plateforme). Les fichiers sont lus **localement après download**. La progression est **persistée server-side** et synchronisée multi-device.
2. **Le backend n'existe pas encore** : toutes les interactions « backend » passent par des `InMemory*Repository` qui simulent la forme finale du système. Pour ce change, l'URL distante est unique et en dur : Big Buck Bunny sur `archive.org` (MP4 H.264 720p ~10 min, ~62 MB, Range-compatible via redirect 302 vers CDN régional). Durée suffisante pour exercer tout le flow resume dialog / 90% / seek / auto-hide.
3. **Le parcours utilisateur-cible** : l'utilisateur tape « Lire » dans la modale → la page player s'ouvre → le download commence → dès qu'un seuil de buffer est atteint, la lecture démarre → le download continue en fond → si une progression existait, un dialogue de reprise est proposé avant la lecture → la progression est sauvegardée en continu → à > 90% le film est marqué complété.

Le kid lock est explicitement exclu : il sera sa propre capability (`kid-lock`) avec overlay Flutter + MethodChannel natifs pour Android (`startLockTask`) et iOS (Accès Guidé). L'intégrer ici ferait gonfler le change au-delà du raisonnable.

## Goals / Non-Goals

**Goals :**
- Passer d'un bouton « Lire » désactivé à une lecture complète depuis la modale jusqu'à la fin du film.
- Poser les contrats Domain (`DownloadRepository`, `WatchProgressRepository`) **identiques à ce qu'ils seront avec le backend HTTP**, de façon à ce que l'arrivée du backend soit un simple remplacement d'implémentation dans les providers.
- Lecture qui démarre dès les premiers octets téléchargés (seuil de buffer ~3s vidéo), pas d'attente de la fin du download.
- Reprise de lecture : dialogue « Reprendre à 1h23 ? » si une progression > 0 existe.
- Sauvegarde de progression périodique (toutes les 10s) + à la fermeture du player + au passage du seuil de complétion (> 90%).
- UX mobile attendue : landscape forcé, immersive system UI, wakelock actif.
- `media_kit` utilisé **directement dans l'UI**, sans port Domain intermédiaire — c'est une lib de rendu, pas un service métier.

**Non-Goals :**
- Kid lock natif (capability dédiée future).
- Contrôles avancés : vitesse, sous-titres, skip ±10s, skip intro, chapitres, choix qualité audio/vidéo.
- Download manager multi-films : queue, concurrence, priorisation, retry avec backoff, notifications système, reprise après crash de l'app.
- Téléchargement en background (OS-level) ou sur réseau cellulaire avec confirmation.
- Persistance disque de la progression (le MVP utilise une Map en RAM ; la perte au redémarrage est acceptée).
- Alimentation de la row `continueWatching` du home — change ultérieur qui consommera le `WatchProgressRepository` introduit ici.
- Écran « Mes téléchargements », gestion du stockage (purge, quotas, suppression manuelle en batch).
- Streaming sans download local (on respecte le design final : lecture locale obligatoire).
- Multi-device synchronisation (le `WatchProgress` n'embarque pas de `deviceId` dans ce change — le backend l'ajoutera).

## Decisions

### 1. Deux capabilities distinctes, un seul change

**Choix :** un change `add-video-playback-and-downloads` contenant deux specs frères : `specs/downloads/spec.md` et `specs/video-playback/spec.md`. Précédent existant : `add-auth-and-profile-selection` a posé exactement ce pattern.

**Raison :** les deux concepts sont métier-distincts (un téléchargement est utile pour la lecture, mais aussi potentiellement pour le mode avion, pour une future feature « mes téléchargements », etc.) mais leur valeur n'existe qu'ensemble côté utilisateur. Les livrer ensemble évite d'archiver une capability sans lecture possible pendant des jours. Les livrer en deux changes séparés multiplierait le cérémonial sans bénéfice.

**Alternative rejetée — un seul spec `video-playback` qui absorbe les downloads :** fuite de concern. Un téléchargement n'est pas de la lecture — il a ses propres règles de statut, de stockage, de cycle de vie.

**Alternative rejetée — deux changes séparés (`add-downloads` puis `add-video-playback`) :** livrerait un system qui télécharge sans jamais lire. Sans valeur intermédiaire observable.

### 2. `media_kit` dans l'UI, pas de port Domain

**Choix :** `media_kit` est importé directement depuis `lib/ui/pages/player/*`. Aucune interface `VideoPlayer` dans le Domain. Aucune implémentation wrapper.

**Raison :** `media_kit` est une lib **de rendu UI**, équivalent à `Image.network` ou un widget de la Material library. Elle n'a pas d'équivalent « fake » qu'on voudrait utiliser en test unitaire (les widget tests Flutter n'instancient de toute façon pas un vrai player natif). Ajouter un port Domain multiplierait les indirections pour une seule impl, fuiterait des types `media_kit` (ou forcerait à en inventer des équivalents), et donnerait une fausse impression de testabilité.

**Conséquence :** la `PlayerPage` et ses widgets contiennent des `Player` et `VideoController` `media_kit`. C'est accepté. Les widget tests vérifieront le comportement observable (affichage des contrôles, lancement du dialogue resume, appels au `WatchProgressRepository`) sans instancier un vrai fichier vidéo.

**Alternative rejetée — port `VideoPlayer { open, play, pause, seek, close, positionStream }` :** ~300 lignes de surface API juste pour wrapper `media_kit`. Pas d'implémentation alternative prévue. Cérémonial pur.

### 3. Le download expose un `Stream<MovieDownload>` plutôt que des callbacks

**Choix :** `DownloadRepository.download(movieId)` retourne `Stream<MovieDownload>`. Chaque événement est un snapshot complet du statut du téléchargement :

```dart
class MovieDownload {
  final String movieId;
  final DownloadStatus status;
  final int bytesReceived;
  final int? bytesTotal;        // null si Content-Length absent
  final String? localPath;      // renseigné dès readyToPlay
  final String? errorMessage;   // renseigné si failed
  final DateTime updatedAt;
}

enum DownloadStatus {
  notStarted,     // jamais vu (utilisé par findByMovieId, pas émis par le stream)
  downloading,    // en cours, localPath null
  readyToPlay,    // seuil atteint, localPath pointe sur le .partial
  complete,       // téléchargement fini, localPath pointe sur le .mp4 définitif
  failed,         // erreur, errorMessage renseigné
  cancelled,      // annulé par l'utilisateur
}
```

**Raison :** un stream convient naturellement à un flux de mises à jour asynchrones. Le widget Flutter consomme via `StreamBuilder` ou `ref.watch` d'un `StreamProvider`. La reprise d'observation (ex: deuxième fois qu'on rouvre la page player alors qu'un download est en cours) est naturelle — le repo peut retourner le stream existant.

**Alternative rejetée — callbacks `onProgress`, `onComplete`, `onError` :** multiplie les points d'entrée, ne compose pas avec Riverpod.

**Alternative rejetée — `Future<MovieDownload>` avec polling :** perd le temps réel de la progression.

### 4. Seuil `readyToPlay` basé sur les octets reçus, pas sur la durée bufférisée

**Choix :** l'InMemory impl émet `DownloadStatus.readyToPlay` dès que `bytesReceived >= 2 * 1024 * 1024` (2 Mo) ET que `bytesReceived >= bytesTotal * 0.03` (3% du fichier). Le `localPath` du `.partial` est alors exposé.

**Raison :** on ne connaît pas la durée vidéo réelle depuis le téléchargement (il faudrait démuxer le MP4). Un seuil en octets + un pourcentage plancher est un proxy simple et robuste pour « le player aura assez de header (moov) + de premiers frames pour démarrer ». 2 Mo suffit largement pour le moov d'un MP4 Web-Optimized à 1080p. 3% garantit qu'on a aussi quelques secondes de stream derrière le moov.

**Alternative rejetée — seuil en secondes de vidéo** : nécessiterait un parsing MP4 côté client ou une métadonnée `duration_seconds` dans le catalogue déjà là, **mais** le mapping octets → secondes n'est pas trivial sans le header. Simpler de rester en octets.

**Alternative rejetée — émettre `readyToPlay` immédiatement au 1er octet** : le moov n'est peut-être pas encore reçu, `media_kit` échouerait à parser l'en-tête.

**Alternative rejetée — attendre `complete`** : viole l'exigence utilisateur « lancer la lecture dès les premiers octets téléchargés ».

### 5. Renommage `.partial` → `.mp4` à la fin du download, transparent pour le player

**Choix :** pendant le download, les bytes sont écrits dans `${documents}/downloads/${movieId}.mp4.partial`. Dès `readyToPlay`, le `localPath` émis pointe sur ce `.partial`. À la fin du download, le repo **renomme** le fichier en `${movieId}.mp4` et émet `complete` avec le nouveau `localPath`.

**Implication :** `media_kit` a ouvert le fichier `.partial` avec un `File()` et un descripteur de fichier. Sur macOS/Linux, un rename ne change rien pour le descripteur déjà ouvert (inode stable). Sur Windows, un rename d'un fichier ouvert en écriture **peut échouer** — on retarde alors le rename jusqu'à la fin de la lecture, ou on émet `complete` avec le `localPath` du `.partial` et on renomme à la prochaine ouverture.

**Mitigation Windows** : cette plateforme n'est pas une cible MVP critique (GLOBALVIEW cible mobile + desktop macOS/Linux). Si le rename échoue, le repo le rejoue silencieusement à la fermeture de la `PlayerPage` ou au prochain `findByMovieId`. Test manuel sur macOS suffisant pour ce change.

**Alternative rejetée — pas de `.partial`, écrire directement dans `.mp4`** : si l'app crashe pendant le download, on a un `.mp4` tronqué qu'on croira complet. Le suffixe `.partial` est un marqueur d'incomplétude sur disque.

### 6. `media_kit` ouvre le fichier local pendant qu'il est encore en écriture

**Choix :** quand le stream émet `readyToPlay` avec `localPath = /docs/downloads/abc.mp4.partial`, la `PlayerPage` instancie :

```dart
final player = Player();
await player.open(Media('file://$localPath'));
await player.play();
```

`media_kit` (libmpv sous le capot) lit le fichier comme une source standard. Tant que `bytesReceived` croît plus vite que la lecture, la playback progresse sans accroc. Si la lecture rattrape l'écriture (ex: réseau lent), le player émettra un évent de buffering.

**Invariant à tenir par l'UI** : tant que le stream de download n'a pas émis `complete`, `seekTo(position)` au-delà de la zone déjà téléchargée doit être désactivé ou rejeté. Implémentation : clamper `position <= (bytesReceived / bytesTotal) * duration` avant d'appeler `seekTo`. Au MVP, on peut simplement masquer la partie non bufférisée de la seek bar (cf. requirement UI).

**Alternative rejetée — streamer l'URL HTTP directement via `media_kit` et télécharger en parallèle** : double flux réseau au premier visionnage. Chemin de code dupliqué (première fois = streaming, visionnages suivants = local).

**Alternative rejetée — mpv `cache-dir` property** : dépendance à la surface d'exposition de cette option par `media_kit` côté Dart ; moins prévisible.

**Alternative rejetée — attendre la fin du download** : viole le goal.

### 7. `WatchProgressRepository` sans `deviceId`

**Choix :** le contrat actuel expose :

```dart
abstract interface class WatchProgressRepository {
  Future<WatchProgress?> findFor({required String profileId, required String movieId});
  Future<void> save(WatchProgress progress);
  Future<List<WatchProgress>> listForProfile(String profileId);
}
```

`WatchProgress` contient `profileId`, `movieId`, `positionSeconds`, `completed`, `updatedAt`. Pas de `deviceId`.

**Raison :** le MVP n'a pas de notion d'identifiant device côté client. Le backend (Phase 2) ajoutera `last_device_id` à `watch_progress` en DB pour distinguer les sources de mise à jour, mais du point de vue du client, `save` est toujours « cette progression vient de ce profil sur ce device ». Le device est inféré côté serveur via le JWT.

**Conséquence :** quand le backend HTTP remplacera l'`InMemoryWatchProgressRepository`, il n'y aura pas de breaking change côté contrat Domain. Le device identifier restera côté infrastructure.

**Alternative rejetée — inclure `deviceId` dans `WatchProgress` dès maintenant** : donnée fantôme en InMemory (pas de device), et donnée que le client n'a pas besoin de connaître en HTTP non plus.

### 8. Sauvegarde de progression : 10s périodique + fin de lecture + complétion

**Choix :** la `PlayerPage` déclenche `SaveWatchProgressUseCase.execute(profileId, movieId, positionSeconds, completed)` :

- **Toutes les 10s** pendant la lecture active (pas en pause).
- **À la fermeture** de la page (`dispose()`), avec la position courante.
- **Au franchissement** du seuil de complétion (`position / duration > 0.9`), avec `completed = true`, une seule fois par lecture.

Le seuil 0.9 est documenté dans GLOBALVIEW. Une fois `completed = true`, on n'écrase plus avec `completed = false` dans la même lecture (même si l'utilisateur seek en arrière).

**Alternative rejetée — sauvegarder à chaque tick (30 fps)** : écriture frénétique pour aucun gain. Le backend HTTP n'accepterait de toute façon pas ce débit.

**Alternative rejetée — ne sauvegarder qu'à la fermeture** : perte de progression si l'app crashe pendant la lecture.

### 9. Dialogue « Reprendre à X ? » bloquant avant ouverture du player

**Choix :** au montage de la `PlayerPage`, le flux est :

1. `GetWatchProgressUseCase.execute(profileId, movieId)` → `WatchProgressDto?`
2. Si progression `null` OU `positionSeconds < 10` OU `completed == true` : pas de dialogue, lecture depuis 0.
3. Sinon : dialogue modal bloquant avec deux actions « Reprendre à {formattedPosition} » (primaire) ou « Recommencer » (secondaire).
4. L'action choisie **détermine la position initiale** passée à `media_kit` lors de l'`open`.

**Condition « < 10s »** : une progression de 3s est du bruit (démarrage + fermeture rapide), pas une reprise utile.

**Condition `completed == true`** : film déjà terminé, proposer de recommencer n'a pas de sens comme dialogue bloquant (ça redémarrera à 0 sans demander).

**Alternative rejetée — toujours afficher le dialogue** : frustrant au rejeu depuis 0 d'un film terminé.

**Alternative rejetée — reprendre silencieusement sans demander** : perd l'agentivité utilisateur — si une position de reprise est incorrecte (ex: fin de film avant les crédits de fin), l'utilisateur préférera recommencer.

### 10. Contrôles du player : `MaterialVideoControls` de media_kit, customisés

**Choix :** la `PlayerPage` utilise les contrôles natifs fournis par `media_kit_video` (`MaterialVideoControls` via `AdaptiveVideoControls`, avec rendu Cupertino-style sur iOS). La page configure l'overlay via `MaterialVideoControlsTheme` :

- `topButtonBar` custom : `IconButton(Icons.close)` + `Text(movieTitle)` ellipsis. Le Close invoque `_onClose()` de la page (sauvegarde progression via `dispose` → navigate to `/home`).
- `bottomButtonBar` : `MaterialPlayOrPauseButton`, `MaterialPositionIndicator`, `Spacer`, `MaterialFullscreenButton`.
- `speedUpOnLongPress: false`, `seekOnDoubleTap: false` — on désactive les gestes "pro" qui surprendraient un enfant.
- `visibleOnMount: true` — les contrôles apparaissent à l'ouverture, auto-hide géré par media_kit (3s par défaut).

**Raison du choix (révisé après exploration initiale) :** une première itération avait câblé un overlay 100% custom (`PlayerControls`, `PlayerSeekBar`). Trois raisons de revenir aux contrôles de la lib :

1. **Gestion des gestes / clavier "gratuite"** : space = play/pause, flèches = seek, accessibilité, tout est déjà câblé par `MaterialVideoControls`. Réécrire ça proprement aurait doublé la surface de code.
2. **Un overlay custom au-dessus du `Video` widget masquait nativement les contrôles internes de media_kit** (le widget affiche `AdaptiveVideoControls` par défaut) — on se retrouvait avec deux couches qui se marchaient dessus : duplicate GlobalKey, RenderFlex overflow, taps interceptés.
3. La personnalisation par le thème (`topButtonBar` / `bottomButtonBar` sont `List<Widget>`) est suffisante pour **intégrer le bouton Kids Lock plus tard** — il s'ajoutera dans le top bar sans refonte.

**Ce qu'on perd par rapport au custom :**
- L'indicateur "buffer = position téléchargée" (la seek bar de media_kit montre le buffer interne de mpv, qui peut différer du download en cours). Jugé cosmétique.
- Le clamp explicite du seek au buffered. mpv bloque automatiquement en lecture (stall bref, puis reprise quand le download rattrape) — équivalent fonctionnel, pas de crash.

**Explicitement hors scope** (pas rendus dans les button bars) : vitesse (0.5x/1x/1.5x/2x) — geste long-press désactivé, bouton absent ; sous-titres — bouton captions absent ; skip ±10s — double-tap désactivé, boutons absents ; chapitres, choix qualité, bouton changement d'audio — absents. Liste alignée avec le non-goal initial.

### 11. Orientation landscape forcée sur mobile, pas sur desktop

**Choix :** à l'entrée de la `PlayerPage` :

```dart
// Détecte si mobile via defaultTargetPlatform
if (isMobile) {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}
```

À la sortie : restauration via `SystemChrome.setPreferredOrientations([])` et `SystemUiMode.edgeToEdge`.

Sur desktop (`isMacOS`, `isLinux`, `isWindows`), pas d'intervention — la fenêtre reste redimensionnable. Le player prend toute la surface disponible.

**Alternative rejetée — forcer landscape partout** : inutile et intrusif sur desktop/tablette.

**Alternative rejetée — détecter l'aspect ratio du screen plutôt que la plateforme** : risque d'interférer avec un iPad en orientation paysage déjà correcte.

### 12. Wakelock pendant la lecture

**Choix :** à l'ouverture de la `PlayerPage`, `WakelockPlus.enable()`. À la fermeture ou à la pause prolongée, `WakelockPlus.disable()`. Pause = désactivation immédiate.

**Raison :** sans wakelock, l'écran s'éteint après le timeout système même si la vidéo joue — inutilisable.

**Détail : désactivation à la pause** — si l'utilisateur met en pause puis va boire un café, pas de raison de maintenir l'écran allumé. Reprise de la pause = reprise du wakelock.

### 13. Architecture des fichiers

```
lib/
├── core/
│   ├── domain/
│   │   ├── model/
│   │   │   ├── movie_download.dart                         [NEW]
│   │   │   │     MovieDownload + DownloadStatus enum
│   │   │   └── watch_progress.dart                         [NEW]
│   │   │         WatchProgress value object
│   │   └── services/
│   │       ├── download.repository.dart                    [NEW]
│   │       │     DownloadRepository interface
│   │       └── watch_progress.repository.dart              [NEW]
│   │             WatchProgressRepository interface
│   └── application/
│       ├── dtos/
│       │   ├── movie_download.dto.dart                     [NEW]
│       │   └── watch_progress.dto.dart                     [NEW]
│       └── usecases/
│           ├── start_movie_download.usecase.dart           [NEW]
│           ├── find_movie_download.usecase.dart            [NEW]
│           ├── cancel_movie_download.usecase.dart          [NEW]
│           ├── delete_movie_download.usecase.dart          [NEW]
│           ├── get_watch_progress.usecase.dart             [NEW]
│           └── save_watch_progress.usecase.dart            [NEW]
├── infrastructure/
│   ├── downloads/
│   │   └── in_memory.download.repository.dart              [NEW]
│   │         dio + path_provider, fixed URL constant,
│   │         .partial → .mp4 rename, readyToPlay threshold
│   ├── watch_progress/
│   │   └── in_memory.watch_progress.repository.dart        [NEW]
│   │         Map<(profileId, movieId), WatchProgress>
│   └── providers/
│       ├── download.repository_provider.dart               [NEW]
│       ├── download.usecases_provider.dart                 [NEW]
│       ├── watch_progress.repository_provider.dart         [NEW]
│       └── watch_progress.usecases_provider.dart           [NEW]
└── ui/
    ├── router/
    │   └── app_router.dart                                 [MODIFIED]
    │         + AppRoutes.player = '/player/:movieId'
    └── pages/
        ├── home/
        │   └── widgets/
        │       └── movie_detail_modal.widget.dart          [MODIFIED]
        │             bouton Lire actif → navigate to player
        └── player/
            ├── player.page.dart                            [NEW]
            │     route /player/:movieId, state machine
            │     downloading → ready → playing
            │     wrap media_kit Video dans un
            │     MaterialVideoControlsTheme custom
            ├── player_engine.dart                          [NEW]
            │     abstract PlayerEngine (test seam)
            ├── media_kit_player_engine.dart                [NEW]
            │     impl prod — Player + VideoController
            │     + Video widget caché dans _surface
            └── widgets/
                ├── player_download_gate.widget.dart        [NEW]
                │     progress bar + bytes + cancel button
                ├── player_error_state.widget.dart          [NEW]
                │     message failed/cancelled + retry/back
                └── resume_dialog.widget.dart               [NEW]
                      "Reprendre à Xh YY ?" / "Recommencer"

pubspec.yaml                                                [MODIFIED]
  + media_kit, media_kit_video, media_kit_libs_video
  + dio
  + path_provider
  + wakelock_plus
```

## Risks / Trade-offs

- **`media_kit` lit un fichier `.partial` en cours d'écriture** → bien supporté sur macOS/Linux (inode stable, `fstat` reflète la taille courante). Sur Windows, `CreateFile` peut refuser si le writer a un `FILE_SHARE_READ` exclusif. **Mitigation** : `dio` via `package:http` ouvre le fichier en `FileMode.writeOnlyAppend` — permissif par défaut. Si problème sur Windows, fallback = lecture démarre après `complete` (perd le bénéfice « play while downloading » uniquement sur Windows). macOS est la cible desktop prioritaire.

- **Rename `.partial` → `.mp4` pendant que le player lit** → sur POSIX, l'inode reste valide pour les descripteurs ouverts. Sur Windows, `MoveFile` échoue sur un fichier ouvert en écriture. **Mitigation** : côté Windows, garder le `.partial` jusqu'à la fermeture du player, renommer ensuite. Le `localPath` émis dans `complete` pointe toujours sur le nom final attendu (`${movieId}.mp4`) ; le repo résout au plus tard à la prochaine `findByMovieId`.

- **Seuil `readyToPlay` trop petit** → `media_kit` peut ouvrir le fichier mais échouer au parse du moov si pas encore téléchargé. **Mitigation** : 2 Mo + 3% est large pour un moov de MP4 Web-Optimized (quelques dizaines de Ko typiquement). La première scénario de test ouvre un vrai BigBuckBunny ; on ajustera si besoin.

- **Seuil `readyToPlay` trop grand** → attente perçue par l'utilisateur. **Mitigation** : 2 Mo sur une connexion raisonnable (≥ 1 Mo/s) = ≤ 2s d'attente. Acceptable comparé au « télécharge avant de jouer ».

- **Progression perdue au redémarrage** (`InMemoryWatchProgressRepository`) → expérience imparfaite pour tester le flux de reprise entre sessions. **Mitigation** : acceptée explicitement par l'utilisateur. Le remplacement par une impl HTTP (ou `shared_preferences` le jour où on a un besoin offline) est trivial, le contrat ne bouge pas.

- **Download qui échoue en cours** → le `.partial` reste sur disque, le stream émet `failed`. **Mitigation** : au prochain `download(movieId)`, le repo reprend via `Range: bytes=X-` où `X = tailleFichier.partial`. `dio` supporte nativement.

- **Pas de queue de downloads** → si l'utilisateur ouvre la modale de plusieurs films en rafale et clique `Lire` partout, on déclenche N downloads concurrents sur le même fichier URL distant. **Mitigation** : au MVP, le comportement attendu est « un à la fois » (un seul film joué à la fois). Le repo `InMemoryDownloadRepository` tient une map `{movieId → activeFuture}` pour dédupliquer une requête sur un movieId déjà en cours — cette dédup est dans le spec. Pas de queue globale entre différents movieIds (non-goal).

- **Kid lock absent** → un enfant peut sortir du player, revenir au home, quitter l'app. **Mitigation** : acceptée explicitement (non-goal). Le kid lock viendra dans sa propre capability et se greffera sur la `PlayerPage` existante.

- **Orientation landscape forcée sur mobile perturbe un utilisateur qui a fait pivoter son téléphone manuellement** → il se retrouve bloqué en landscape à la fin du film tant que la page n'est pas dispose. **Mitigation** : la restauration se fait en `dispose()`. Si crash, le premier cold start remet les orientations par défaut.

- **`media_kit_libs_video` ajoute des binaires natifs conséquents** (~10-30 Mo selon la plateforme) → taille de l'app en hausse. **Mitigation** : acceptée, c'est le prix de la compatibilité multi-plateforme. Alternative `video_player` (Flutter officiel) est moins capable et ne couvre pas desktop Linux.

- **URL stub unique pour tous les films** → l'expérience est fonctionnellement réelle, mais visuellement les 12 films du catalogue jouent tous la même vidéo BigBuckBunny. **Mitigation** : c'est le but. Le test du *flow* (download, reprise, progression) ne dépend pas du contenu.

## Open Questions

Aucune bloquante.

- **Taille exacte du seuil `readyToPlay`** (2 Mo + 3%) : à calibrer pendant l'implémentation si l'ouverture du fichier par `media_kit` échoue avec ces valeurs. Ajustable sans casser le contrat.
- **Fréquence exacte de la sauvegarde périodique** (10s) : GLOBALVIEW mentionne 10s ; on reste là-dessus. Ajustable sans casser le contrat.
- **Seuil exact de complétion** (> 0.9) : idem GLOBALVIEW.
- **Seuil minimum pour dialogue de reprise** (>= 10s) : à valider à l'usage ; 10s semble raisonnable pour ignorer les ouvertures accidentelles.
- **Comportement si `bytesTotal` est null** (Content-Length absent de la réponse HTTP) : le stream émet `bytesTotal: null` pendant le download, `readyToPlay` se déclenche sur `bytesReceived >= 2 Mo` seul (pas de critère % de fichier). À tester contre l'URL stub choisie.
