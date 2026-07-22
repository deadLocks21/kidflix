import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'github.dart';
import 'log.dart';
import 'net.dart';

/// Télécharge [asset] dans un fichier temporaire via l'outil HTTP système
/// (cf. [httpDownload] : respecte le magasin de certificats Windows / proxys).
Future<File> downloadAsset(ReleaseAsset asset, String tmpDir, Log log) async {
  Directory(tmpDir).createSync(recursive: true);
  final dest = File(p.join(tmpDir, asset.name));

  log('Téléchargement de ${asset.name} (${asset.size ~/ 1024} Ko)…');
  httpDownload(
    asset.url,
    dest.path,
    headers: {'User-Agent': 'kidflix-updater'},
  );
  log('Téléchargé ${asset.name}');
  return dest;
}

/// Installe l'app contenue dans [archiveFile] dans [versionDir].
///  - Windows : décompresse le `.zip` (kidflix.exe + dll + data/) à la racine.
///  - Linux   : extrait l'AppImage en `squashfs-root/`.
void installAppArtifact(File archiveFile, String versionDir, Log log) {
  final dir = Directory(versionDir);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  if (Platform.isWindows) {
    _extractZip(archiveFile.path, versionDir, log);
  } else {
    _extractAppImage(archiveFile, versionDir, log);
  }
}

/// Déploie l'AppImage [archiveFile] dans [versionDir] en l'**extrayant**, au
/// lieu de la laisser telle quelle.
///
/// Une AppImage de type 2 se monte via FUSE 2 à chaque lancement, or `libfuse2`
/// n'est plus installée par défaut depuis Ubuntu 22.04 : l'exécuter directement
/// échoue sur `error loading libfuse.so.2`. Comme l'updater lance l'app sans
/// console, cet échec serait parfaitement silencieux côté utilisateur.
///
/// `--appimage-extract` est pris en charge par le runtime AppImage lui-même,
/// sans FUSE. On l'applique une fois à l'installation plutôt qu'à chaque
/// démarrage (`--appimage-extract-and-run`), pour ne pas repayer la
/// décompression du bundle à chaque lancement.
void _extractAppImage(File archiveFile, String versionDir, Log log) {
  final image = File(p.join(versionDir, 'Kidflix.AppImage'));
  archiveFile.copySync(image.path);
  Process.runSync('chmod', ['+x', image.path]);

  // `--appimage-extract` écrit toujours dans `squashfs-root/` du répertoire
  // courant : d'où le workingDirectory plutôt qu'un chemin de sortie.
  final result = Process.runSync(image.path, const [
    '--appimage-extract',
  ], workingDirectory: versionDir);

  final appRun = File(p.join(versionDir, 'squashfs-root', 'AppRun'));
  if (result.exitCode != 0 || !appRun.existsSync()) {
    // On garde l'AppImage : `Layout.appExecutable` retombera dessus, ce qui
    // reste jouable si l'hôte a libfuse2.
    log.error(
      'Extraction de l\'AppImage échouée (code ${result.exitCode}) — '
      'lancement direct de l\'image',
      result.stderr,
    );
    return;
  }

  // Le contenu extrait fait foi : inutile de garder l'image en double.
  image.deleteSync();
  Process.runSync('chmod', ['+x', appRun.path]);
  log('AppImage extraite : ${appRun.path}');
}

void _extractZip(String zipPath, String destDir, Log log) {
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeBuffer(input);
    for (final entry in archive) {
      final outPath = p.join(destDir, entry.name);
      if (entry.isFile) {
        final out = OutputFileStream(outPath);
        try {
          entry.writeContent(out);
        } finally {
          out.closeSync();
        }
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }
    log('Archive décompressée dans $destDir');
  } finally {
    input.closeSync();
  }
}
