import 'dart:convert';
import 'dart:io';

import 'layout.dart';
import 'net.dart';

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
  ///  - Windows : `kidflix-windows-<v>.zip`
  ///  - macOS   : `kidflix-macos-<v>.zip` (.app signé Developer ID zippé)
  ///  - Linux   : `kidflix-linux-<v>-x86_64.AppImage`
  ///
  /// Les regex restent volontairement larges : elles doivent continuer à matcher
  /// les anciens noms (`kidflix-windows-<v>-<run>.zip`,
  /// `Kidflix-<v>-<run>-x86_64.AppImage`) et, surtout, un updater déjà installé
  /// applique les regex de SA version aux assets des releases futures. Le nom des
  /// assets produits par la CI est donc un contrat : cf. le job `release` de
  /// `.github/workflows/release.yml`.
  ReleaseAsset? get appAsset {
    final RegExp re;
    if (Platform.isWindows) {
      re = RegExp(r'^kidflix-windows-.*\.zip$', caseSensitive: false);
    } else if (Platform.isMacOS) {
      re = RegExp(r'^kidflix-macos-.*\.zip$', caseSensitive: false);
    } else {
      re = RegExp(r'x86_64\.AppImage$', caseSensitive: false);
    }
    return _firstWhereOrNull(assets, (a) => re.hasMatch(a.name));
  }

  /// Asset du binaire updater lui-même (pour l'auto-mise à jour de l'updater).
  ///  - Windows : `kidflix-updater-windows.exe`
  ///  - Linux   : `kidflix-updater-linux`
  ///  - macOS   : `kidflix-installer-macos-<v>.zip` — un `.app` notarisé
  ///    + staplé (pas un binaire nu, qui serait tué par Gatekeeper au 1ᵉʳ
  ///    téléchargement). L'auto-MAJ en extrait le binaire interne (cf.
  ///    Installer._selfUpdateUpdater). Téléchargé par curl, donc jamais mis en
  ///    quarantaine côté install existante.
  ///
  /// Deux noms à ne pas casser côté CI : l'installateur macOS doit garder le
  /// préfixe `kidflix-installer-macos-` (renommé en `kidflix-macos-installer-*`
  /// il matcherait la regex de [appAsset] et l'app s'installerait depuis
  /// l'installateur), et les binaires updater doivent rester **non versionnés** —
  /// les installations existantes les cherchent au nom exact.
  ReleaseAsset? get updaterAsset {
    if (Platform.isMacOS) {
      final re =
          RegExp(r'^kidflix-installer-macos-.*\.zip$', caseSensitive: false);
      return _firstWhereOrNull(assets, (a) => re.hasMatch(a.name));
    }
    final wanted = Platform.isWindows
        ? 'kidflix-updater-windows.exe'
        : 'kidflix-updater-linux';
    return _firstWhereOrNull(assets, (a) => a.name == wanted);
  }
}

/// Récupère la dernière release publiée du dépôt public Kidflix.
/// [maxTimeSec] court : on ne veut pas bloquer le lancement de l'app si le
/// réseau est lent ou absent.
Future<Release> fetchLatestRelease({int maxTimeSec = 8}) async {
  final url =
      'https://api.github.com/repos/${Layout.repoOwner}/${Layout.repoName}/releases/latest';
  final body = httpGetString(
    url,
    headers: {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'kidflix-updater',
    },
    maxTimeSec: maxTimeSec,
  );

  final json = jsonDecode(body) as Map<String, dynamic>;
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
