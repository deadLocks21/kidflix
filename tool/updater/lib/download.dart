import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'github.dart';
import 'log.dart';

/// Télécharge [asset] dans un fichier temporaire, en loggant la progression.
Future<File> downloadAsset(ReleaseAsset asset, String tmpDir, Log log) async {
  Directory(tmpDir).createSync(recursive: true);
  final dest = File(p.join(tmpDir, asset.name));

  final client = http.Client();
  try {
    final req = http.Request('GET', Uri.parse(asset.url))
      ..headers['User-Agent'] = 'kidflix-updater';
    final resp = await client.send(req);
    if (resp.statusCode != 200) {
      throw HttpException(
        'Téléchargement ${asset.name} : HTTP ${resp.statusCode}',
      );
    }

    final total = resp.contentLength ?? asset.size;
    final sink = dest.openWrite();
    var received = 0;
    var lastLoggedPct = -10;
    await resp.stream.forEach((chunk) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        final pct = (received * 100 ~/ total);
        if (pct >= lastLoggedPct + 10) {
          lastLoggedPct = pct;
          log('  téléchargement ${asset.name} : $pct%');
        }
      }
    });
    await sink.close();
    log('Téléchargé ${asset.name} (${received ~/ 1024} Ko)');
    return dest;
  } finally {
    client.close();
  }
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
