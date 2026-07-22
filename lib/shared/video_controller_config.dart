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
VideoControllerConfiguration videoControllerConfiguration() =>
    VideoControllerConfiguration(
      hwdec: Platform.isLinux ? 'no' : null,
      enableHardwareAcceleration: !Platform.isLinux,
    );
