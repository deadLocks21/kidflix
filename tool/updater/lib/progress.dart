import 'dart:io';

import 'package:path/path.dart' as p;

import 'layout.dart';
import 'log.dart';

/// Fenêtre de progression affichée pendant qu'une mise à jour se
/// télécharge/installe — et seulement dans ce cas.
///
/// L'affichage est délégué à **l'app Kidflix elle-même** : l'updater lance
/// `current/kidflix(.exe) --updating --status <fichier>`, qui ouvre une petite
/// fenêtre native rendue par Flutter (fiable, contrairement à une fenêtre
/// PowerShell/WinForms). La communication passe par le fichier d'état :
/// l'updater y écrit le libellé d'étape, puis le sentinel `__DONE__` que la
/// fenêtre détecte pour se fermer.
///
/// Best-effort : si quoi que ce soit échoue, la MAJ se poursuit sans IHM.
///
/// NB d'amorçage : c'est l'app **déjà installée** qui rend la fenêtre. Si elle
/// est antérieure au support de `--updating`, elle lancerait l'app complète au
/// lieu du splash — d'où le garde-fou de version côté [Installer].
class ProgressWindow {
  ProgressWindow._(this._process, this._statusFile)
    : _shown = Stopwatch()..start();

  final Process _process;
  final File _statusFile;
  final Stopwatch _shown;

  static const _doneSentinel = '__DONE__';

  /// Durée d'affichage minimale, pour qu'une MAJ rapide ne fasse pas juste
  /// « flasher » la fenêtre.
  static const _minDisplay = Duration(milliseconds: 1200);

  static Future<ProgressWindow?> start(Layout layout, Log log) async {
    try {
      final exe = layout.appExecutable;
      if (!File(exe).existsSync()) {
        log.error('Splash : exécutable introuvable ($exe)');
        return null;
      }
      final statusFile = File(p.join(layout.root, '.update-status'))
        ..writeAsStringSync('Préparation…');

      final process = await Process.start(
        exe,
        ['--updating', '--status', statusFile.path],
        mode: ProcessStartMode.detached,
        workingDirectory: layout.currentLink,
      );
      return ProgressWindow._(process, statusFile);
    } catch (e) {
      log.error('Fenêtre de progression non affichée', e);
      return null;
    }
  }

  /// Met à jour le libellé d'étape affiché.
  void status(String message) {
    try {
      _statusFile.writeAsStringSync(message);
    } catch (_) {}
  }

  /// Demande la fermeture de la fenêtre et nettoie le fichier d'état. Attend
  /// que la fenêtre (et donc le process app) se ferme, car l'appelant purge
  /// ensuite l'ancienne version dont ce process pouvait dépendre.
  Future<void> close() async {
    final remaining = _minDisplay - _shown.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

    try {
      _statusFile.writeAsStringSync(_doneSentinel);
    } catch (_) {}
    // Laisse la fenêtre lire le sentinel (poll 200 ms) et se fermer.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    try {
      _process.kill(); // backstop si elle ne s'est pas fermée seule.
    } catch (_) {}
    try {
      if (_statusFile.existsSync()) _statusFile.deleteSync();
    } catch (_) {}
  }
}
