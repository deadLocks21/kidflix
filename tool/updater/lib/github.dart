import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'layout.dart';

class ReleaseAsset {
  ReleaseAsset({required this.name, required this.url, required this.size});

  final String name;
  final String url; // browser_download_url
  final int size;
}

class Release {
  Release({required this.tag, required this.version, required this.assets});

  final String tag; // ex. v1.6.1
  final String version; // ex. 1.6.1
  final List<ReleaseAsset> assets;

  /// Asset correspondant à l'app pour la plateforme courante.
  ///  - Windows : `kidflix-windows-<v>-<run>.zip`
  ///  - Linux   : `Kidflix-<v>-<run>-x86_64.AppImage`
  ReleaseAsset? get appAsset {
    final re = Platform.isWindows
        ? RegExp(r'^kidflix-windows-.*\.zip$', caseSensitive: false)
        : RegExp(r'x86_64\.AppImage$', caseSensitive: false);
    return _firstWhereOrNull(assets, (a) => re.hasMatch(a.name));
  }

  /// Asset du binaire updater lui-même (pour l'auto-mise à jour de l'updater).
  ///  - Windows : `kidflix-updater-windows.exe`
  ///  - Linux   : `kidflix-updater-linux`
  ReleaseAsset? get updaterAsset {
    final wanted = Platform.isWindows
        ? 'kidflix-updater-windows.exe'
        : 'kidflix-updater-linux';
    return _firstWhereOrNull(assets, (a) => a.name == wanted);
  }
}

/// Récupère la dernière release publiée du dépôt public Kidflix.
/// [timeout] court : on ne veut pas bloquer le lancement de l'app si le
/// réseau est lent ou absent.
Future<Release> fetchLatestRelease({
  Duration timeout = const Duration(seconds: 8),
}) async {
  final uri = Uri.parse(
    'https://api.github.com/repos/${Layout.repoOwner}/${Layout.repoName}/releases/latest',
  );
  final resp = await http
      .get(
        uri,
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'kidflix-updater',
        },
      )
      .timeout(timeout);

  if (resp.statusCode != 200) {
    throw HttpException(
      'GitHub a répondu ${resp.statusCode} pour la dernière release',
      uri: uri,
    );
  }

  final json = jsonDecode(resp.body) as Map<String, dynamic>;
  final tag = json['tag_name'] as String;
  final assets = (json['assets'] as List)
      .cast<Map<String, dynamic>>()
      .map(
        (a) => ReleaseAsset(
          name: a['name'] as String,
          url: a['browser_download_url'] as String,
          size: (a['size'] as num).toInt(),
        ),
      )
      .toList();

  return Release(tag: tag, version: normalizeVersion(tag), assets: assets);
}

/// `v1.6.1` -> `1.6.1`.
String normalizeVersion(String tag) =>
    tag.startsWith('v') ? tag.substring(1) : tag;

/// Compare deux versions type `1.6.10` : <0 si [a]<[b], 0 si égales, >0 sinon.
int compareVersions(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

List<int> _parts(String v) => v
    .split('.')
    .map(
      (s) => int.tryParse(RegExp(r'\d+').firstMatch(s)?.group(0) ?? '0') ?? 0,
    )
    .toList();

T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
  for (final e in list) {
    if (test(e)) return e;
  }
  return null;
}
