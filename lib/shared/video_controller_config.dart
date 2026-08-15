import 'dart:io';

import 'package:media_kit_video/media_kit_video.dart';

/// Configuration commune aux deux [VideoController] de l'app : le lecteur
/// principal et la bande-annonce des modals de détail.
///
/// Sous Linux, les deux étages de la chaîne vidéo de `media_kit` s'appuient
/// par défaut sur du matériel que l'AppImage ne peut pas embarquer.
///
/// **Décodage** (`hwdec`) — `media_kit` force `hwdec=auto` dès que la
/// configuration ne dit rien, ce qui pousse mpv à sonder les backends de
/// décodage matériel (VDPAU, VA-API…). Ces backends sont des `.so` chargés
/// dynamiquement DEPUIS L'HÔTE : couplés au driver GPU, ils sont
/// volontairement absents de l'AppImage — et un `dlopen` runtime échappe par
/// nature au contrôle `ldd` de la CI. Quand le backend retenu ne se charge
/// pas, mpv n'assure aucun repli logiciel : il échoue sur « Could not open
/// codec ».
///
/// **Rendu** (`enableHardwareAcceleration`) — le chemin GPU crée un contexte
/// GL GDK, enregistre une `FlTextureGL` et ouvre un `mpv_render_context` en
/// `MPV_RENDER_API_TYPE_OPENGL`. `media_kit` ne retombe sur le rendu logiciel
/// que si l'une de ces étapes échoue franchement. Or sur GPU hybride, elles
/// réussissent toutes puis l'interop échoue en silence : mpv décode, la
/// texture est bien dimensionnée, mais aucune frame n'y arrive — d'où une
/// image uniformément bleue et aucun message d'erreur. Le chemin logiciel,
/// lui, fait rendre mpv dans un simple buffer CPU (`rgb0`) transmis à une
/// `FlTextureSW` : aucune interop GL, donc aucun couplage au driver.
///
/// On force donc les deux étages en logiciel sous Linux, seul chemin dont
/// l'AppImage embarque réellement les dépendances. Les autres plateformes
/// gardent l'accélération matérielle, où elle est fiable et où elle compte
/// vraiment (autonomie sur mobile).
///
/// ## macOS : rendu logiciel, pour une raison différente
///
/// Sous macOS le chemin GPU décode bien mais présente mal. Mesuré via
/// `PlaybackDiagnostics` sur un HEVC 1080p 24 fps lu depuis un fichier
/// local complet : `drop_dec=0` (VideoToolbox suit sans effort),
/// `raster_ms=1` et `slow=0` (le compositeur Flutter est au repos),
/// `rebuffer=0` — et pourtant 4 à 9 images par seconde jetées à la
/// présentation (`drop_vo`), en continu. Le même fichier est fluide dans
/// IINA sur la même machine, ce qui situe le problème dans le couplage
/// entre mpv et la texture Flutter, pas dans mpv ni dans Flutter.
///
/// La cause est le rendez-vous entre les deux : avec `vo=libmpv` c'est
/// l'hôte qui possède l'horloge de présentation, Flutter ne repeint que
/// quand la texture est marquée sale — donc exactement à la cadence du
/// film, sans aucune marge — et toute image récupérée en retard est
/// perdue. (Corollaire vérifié : dire à mpv la vraie cadence de l'écran
/// via `override-display-fps` + `video-sync=display-resample` rend les
/// choses bien pires, mpv produisant alors des images que personne ne
/// vient chercher. Ne pas retenter.)
///
/// Le chemin logiciel évite l'interop GL et passe par une copie de
/// buffer, ce qui découple les deux horloges. `hwdec` reste à `auto` —
/// `media_kit` le résout indépendamment de ce drapeau, donc le décodage
/// demeure sur VideoToolbox et seul l'étage de présentation change.
///
/// Résultat mesuré : `drop_vo` passe de 4-9 images/s en continu à 0 sur
/// la grande majorité des fenêtres, avec un résiduel d'environ 1 image/s
/// par intermittence. `frames=120` par fenêtre de 5 s, soit exactement
/// la cadence du film.
///
/// Ce résiduel n'a pas de correction connue côté application, et deux
/// tentatives ont échoué — les consigner évite de les refaire :
/// forcer la boucle de rendu Flutter à 120 Hz pendant la lecture (un
/// `Ticker` repeignant en continu) fait *empirer* `drop_vo` d'un facteur
/// 25, et `video-sync=display-resample` effondre la synchro A/V. La
/// corrélation qui avait suggéré la première — les fenêtres à haute
/// cadence de rendu montraient zéro drop — était une causalité inversée :
/// c'est mpv qui, ne perdant pas d'images, provoquait plus de mises à
/// jour de texture, donc plus de frames Flutter. Le résiduel appartient
/// au chemin de texture de `media_kit` sous macOS.
VideoControllerConfiguration videoControllerConfiguration() =>
    VideoControllerConfiguration(
      hwdec: Platform.isLinux ? 'no' : null,
      enableHardwareAcceleration: !Platform.isLinux && !Platform.isMacOS,
    );
