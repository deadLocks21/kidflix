import 'dart:io';

import 'package:media_kit_video/media_kit_video.dart';

/// Configuration commune aux deux [VideoController] de l'app : le lecteur
/// principal et la bande-annonce des modals de détail.
///
/// Sous Linux, `media_kit` force `hwdec=auto` dès que la configuration ne dit
/// rien, ce qui pousse mpv à sonder les backends de décodage matériel (VDPAU,
/// VA-API…). Or ces backends sont des `.so` chargés dynamiquement **depuis
/// l'hôte** : couplés au driver GPU, ils sont volontairement absents de
/// l'AppImage — et un `dlopen` runtime échappe par nature au contrôle `ldd`
/// de la CI. Quand le backend retenu ne se charge pas, mpv n'assure aucun
/// repli logiciel : il échoue sur « Could not open codec » pour les flux
/// réseau, et laisse la texture vide pour les fichiers locaux (écran bleu —
/// Y=U=V=0 en YUV).
///
/// `hwdec: 'no'` impose donc le décodage logiciel sous Linux, seul chemin dont
/// l'AppImage embarque réellement les dépendances. Les autres plateformes
/// gardent l'accélération matérielle, où elle est fiable et où elle compte
/// vraiment (autonomie sur mobile).
///
/// À ne pas confondre avec `enableHardwareAcceleration`, réglage distinct qui
/// porte sur le *rendu* de la texture et non sur le *décodage* : il reste à sa
/// valeur par défaut, le rendu GPU fonctionnant correctement ici.
VideoControllerConfiguration videoControllerConfiguration() =>
    VideoControllerConfiguration(hwdec: Platform.isLinux ? 'no' : null);
