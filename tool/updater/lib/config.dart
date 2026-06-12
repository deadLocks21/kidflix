import 'dart:convert';
import 'dart:io';

import 'layout.dart';

/// État persistant d'une installation, sérialisé dans `<root>/config.json`.
class Config {
  Config({required this.root, required this.installedVersion, this.lastCheck});

  /// Racine d'installation (redondant avec l'emplacement, mais pratique).
  String root;

  /// Version actuellement pointée par `current`, ex. `1.6.1` (sans le `v`).
  String installedVersion;

  /// Horodatage ISO-8601 du dernier check, purement informatif.
  String? lastCheck;

  factory Config.fromJson(Map<String, dynamic> json) => Config(
    root: json['root'] as String,
    installedVersion: json['installedVersion'] as String,
    lastCheck: json['lastCheck'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'root': root,
    'installedVersion': installedVersion,
    if (lastCheck != null) 'lastCheck': lastCheck,
  };

  static Config? load(Layout layout) {
    final f = File(layout.configFile);
    if (!f.existsSync()) return null;
    return Config.fromJson(
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  void save(Layout layout) {
    File(
      layout.configFile,
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(toJson()));
  }
}
