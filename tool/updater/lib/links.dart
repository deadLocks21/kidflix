import 'dart:io';

import 'log.dart';

/// Fait pointer `current` (le lien stable) vers [targetVersionDir].
///
/// L'opération est conçue pour ne jamais casser le lien : on prépare un
/// nouveau lien à côté puis on bascule.
///  - Linux   : symlink temporaire + `rename()` atomique par-dessus l'ancien.
///  - Windows : jonction de répertoire (`mklink /J`) — pas besoin de droits
///    admin ni du Mode Développeur, contrairement aux symlinks. La bascule
///    n'est pas atomique (fenêtre de quelques ms) mais sans perte.
void swapCurrent(String currentLink, String targetVersionDir, Log log) {
  if (Platform.isWindows) {
    _swapWindows(currentLink, targetVersionDir, log);
  } else {
    _swapPosix(currentLink, targetVersionDir, log);
  }
  log('current -> $targetVersionDir');
}

void _swapPosix(String currentLink, String target, Log log) {
  final tmp = '$currentLink.new';
  final tmpLink = Link(tmp);
  if (tmpLink.existsSync()) tmpLink.deleteSync();
  tmpLink.createSync(target);
  // rename() remplace atomiquement le symlink existant.
  tmpLink.renameSync(currentLink);
}

void _swapWindows(String currentLink, String target, Log log) {
  final tmp = '$currentLink.new';
  _removeJunctionWindows(tmp);

  final mk = Process.runSync('cmd', ['/c', 'mklink', '/J', tmp, target]);
  if (mk.exitCode != 0) {
    throw ProcessException(
      'cmd',
      ['mklink', '/J', tmp, target],
      (mk.stderr as String?) ?? 'mklink a échoué',
      mk.exitCode,
    );
  }

  _removeJunctionWindows(currentLink);
  // Renomme la nouvelle jonction sur le nom définitif.
  Directory(tmp).renameSync(currentLink);
}

/// Supprime une jonction Windows SANS toucher à son contenu cible.
/// `rmdir` sur une jonction retire uniquement le lien.
void _removeJunctionWindows(String path) {
  if (!Directory(path).existsSync() && !Link(path).existsSync()) return;
  Process.runSync('cmd', ['/c', 'rmdir', path]);
}
