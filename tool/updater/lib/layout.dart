import 'dart:io';

import 'package:path/path.dart' as p;

/// Décrit l'arborescence d'une installation Kidflix enracinée en [root] :
///
/// ```
/// <root>/
///   versions/<v>/        contenu d'une version (kidflix.exe + dll + data/, ou AppImage)
///   current              jonction (Windows) / symlink (Linux) -> versions/<v>
///   updater/             le binaire updater relocalisé (emplacement stable)
///   config.json          { root, installedVersion, ... }
///   updater.log
///   launch.vbs           (Windows) wrapper de lancement caché
/// ```
class Layout {
  Layout(this.root);

  final String root;

  /// Dépôt GitHub public hébergeant les releases.
  static const repoOwner = 'deadLocks21';
  static const repoName = 'kidflix';

  /// Racine d'installation proposée par défaut (modifiable à l'install).
  static String defaultRoot() {
    if (Platform.isWindows) {
      final local =
          _env('LOCALAPPDATA') ??
          p.join(_env('USERPROFILE') ?? r'C:\', 'AppData', 'Local');
      return p.join(local, 'Kidflix');
    }
    final xdg = _env('XDG_DATA_HOME');
    final base = (xdg != null && xdg.isNotEmpty)
        ? xdg
        : p.join(_env('HOME') ?? '.', '.local', 'share');
    return p.join(base, 'Kidflix');
  }

  String get versionsDir => p.join(root, 'versions');
  String get currentLink => p.join(root, 'current');
  String get updaterDir => p.join(root, 'updater');
  String get configFile => p.join(root, 'config.json');
  String get logFile => p.join(root, 'updater.log');
  String get launchVbs => p.join(root, 'launch.vbs');

  String versionDir(String version) => p.join(versionsDir, version);

  /// Nom du binaire updater une fois relocalisé sous `<root>/updater/`.
  String get updaterExe => p.join(
    updaterDir,
    Platform.isWindows ? 'kidflix-updater.exe' : 'kidflix-updater',
  );

  /// Exécutable de l'app à lancer, via le lien `current` (jamais versionné).
  String get appExecutable => Platform.isWindows
      ? p.join(currentLink, 'kidflix.exe')
      : p.join(currentLink, 'Kidflix.AppImage');

  bool get isInstalled => File(configFile).existsSync();

  // ── Découverte d'une install existante ───────────────────────────────────

  /// Fichier-pointeur hors-racine, qui mémorise OÙ Kidflix est installé.
  /// Permet à un updater fraîchement téléchargé (dans Téléchargements) de
  /// retrouver l'install existante au lieu de relancer une installation.
  static String pointerFile() {
    if (Platform.isWindows) {
      final appData =
          _env('APPDATA') ??
          p.join(_env('USERPROFILE') ?? r'C:\', 'AppData', 'Roaming');
      return p.join(appData, 'Kidflix', 'install.path');
    }
    final xdg = _env('XDG_CONFIG_HOME');
    final base = (xdg != null && xdg.isNotEmpty)
        ? xdg
        : p.join(_env('HOME') ?? '.', '.config');
    return p.join(base, 'kidflix', 'install.path');
  }

  /// Résout une installation existante, dans l'ordre :
  ///  1. la racine déduite de l'emplacement du binaire (`<root>/updater/exe`) ;
  ///  2. la racine mémorisée dans le fichier-pointeur.
  /// Retourne `null` si aucune install valide n'est trouvée.
  static Layout? resolveExisting() {
    // 1. binaire exécuté depuis `<root>/updater/` ?
    final exeDir = p.dirname(Platform.resolvedExecutable);
    if (p.basename(exeDir) == 'updater') {
      final candidate = Layout(p.dirname(exeDir));
      if (candidate.isInstalled) return candidate;
    }
    // 2. fichier-pointeur
    final pointer = File(pointerFile());
    if (pointer.existsSync()) {
      final root = pointer.readAsStringSync().trim();
      if (root.isNotEmpty) {
        final candidate = Layout(root);
        if (candidate.isInstalled) return candidate;
      }
    }
    return null;
  }

  void writePointer() {
    final f = File(pointerFile());
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(root);
  }

  static String? _env(String key) => Platform.environment[key];
}
