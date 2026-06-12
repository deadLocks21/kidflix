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
///  - Linux   : place l'AppImage en `Kidflix.AppImage` et la rend exécutable.
void installAppArtifact(File archiveFile, String versionDir, Log log) {
  final dir = Directory(versionDir);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  if (Platform.isWindows) {
    _extractZip(archiveFile.path, versionDir, log);
  } else {
    final target = File(p.join(versionDir, 'Kidflix.AppImage'));
    archiveFile.copySync(target.path);
    Process.runSync('chmod', ['+x', target.path]);
    log('AppImage installée : ${target.path}');
  }
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
