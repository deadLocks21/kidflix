import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'layout.dart';
import 'log.dart';

/// Choix possibles renvoyés par la fenêtre de prompt de mise à jour.
enum UpdateChoice { update, later, skip }

/// Fenêtre de mise à jour, rendue par l'app Kidflix elle-même
/// (`current/kidflix --updating …`) — fiable, contrairement à PowerShell.
///
/// Deux modes :
///  - **prompt** : propose « Mettre à jour / Plus tard / Ignorer » ; l'app écrit
///    le choix dans le fichier de choix, que [waitForChoice] relit. Sur
///    « Mettre à jour », la fenêtre bascule sur la vue progression et reste
///    ouverte ; sinon l'app se ferme.
///  - **progress** : barre de progression directe (replis pour les apps qui
///    connaissent `--updating` mais pas encore `--prompt`).
///
/// Communication par fichiers : `.update-status` (libellé d'étape + sentinel
/// `__DONE__`) et `.update-choice` (choix utilisateur).
class ProgressWindow {
  ProgressWindow._(this._process, this._statusFile, this._choiceFile)
    : _shown = Stopwatch()..start();

  final Process _process;
  final File _statusFile;
  final File? _choiceFile;
  final Stopwatch _shown;

  static const _doneSentinel = '__DONE__';
  static const _minDisplay = Duration(milliseconds: 1200);

  /// Lance la fenêtre en mode **prompt** (3 boutons) pour [newVersion].
  static Future<ProgressWindow?> startPrompt(
    Layout layout,
    Log log,
    String newVersion,
  ) => _start(layout, log, promptVersion: newVersion);

  /// Lance la fenêtre en mode **progression** directe (sans prompt).
  static Future<ProgressWindow?> startProgress(Layout layout, Log log) =>
      _start(layout, log);

  static Future<ProgressWindow?> _start(
    Layout layout,
    Log log, {
    String? promptVersion,
  }) async {
    try {
      final exe = layout.appExecutable;
      if (!File(exe).existsSync()) {
        log.error('Splash : exécutable introuvable ($exe)');
        return null;
      }
      final statusFile = File(p.join(layout.root, '.update-status'))
        ..writeAsStringSync('Préparation…');

      final args = ['--updating', '--status', statusFile.path];
      File? choiceFile;
      if (promptVersion != null) {
        choiceFile = File(p.join(layout.root, '.update-choice'));
        if (choiceFile.existsSync()) choiceFile.deleteSync();
        args.addAll([
          '--prompt',
          '--new-version',
          promptVersion,
          '--choice',
          choiceFile.path,
        ]);
      }

      // Mode normal (pas detached) pour pouvoir détecter la fermeture de la
      // fenêtre via exitCode ; on draine les flux pour ne pas bloquer l'app.
      final process = await Process.start(
        exe,
        args,
        mode: ProcessStartMode.normal,
        workingDirectory: layout.currentLink,
      );
      process.stdout.drain<void>();
      process.stderr.drain<void>();

      return ProgressWindow._(process, statusFile, choiceFile);
    } catch (e) {
      log.error('Fenêtre de progression non affichée', e);
      return null;
    }
  }

  /// Attend le choix de l'utilisateur. Si la fenêtre est fermée sans choix
  /// (croix, crash), on renvoie [UpdateChoice.later] pour ne jamais bloquer.
  Future<UpdateChoice> waitForChoice() async {
    final choiceFile = _choiceFile;
    if (choiceFile == null) return UpdateChoice.update;

    final completer = Completer<UpdateChoice>();
    final poll = Timer.periodic(const Duration(milliseconds: 200), (t) {
      try {
        if (!choiceFile.existsSync()) return;
        final txt = choiceFile.readAsStringSync().trim();
        final choice = switch (txt) {
          'update' => UpdateChoice.update,
          'skip' => UpdateChoice.skip,
          'later' => UpdateChoice.later,
          _ => null,
        };
        if (choice != null && !completer.isCompleted) {
          t.cancel();
          completer.complete(choice);
        }
      } catch (_) {}
    });
    // Fenêtre fermée sans choix -> « plus tard ».
    unawaited(
      _process.exitCode.then((_) {
        if (!completer.isCompleted) {
          poll.cancel();
          completer.complete(UpdateChoice.later);
        }
      }),
    );
    return completer.future;
  }

  /// Met à jour le libellé d'étape affiché (vue progression).
  void status(String message) {
    try {
      _statusFile.writeAsStringSync(message);
    } catch (_) {}
  }

  /// Demande la fermeture de la fenêtre et nettoie les fichiers. Attend que la
  /// fenêtre se ferme (l'appelant purge ensuite l'ancienne version).
  Future<void> close() async {
    final remaining = _minDisplay - _shown.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

    try {
      _statusFile.writeAsStringSync(_doneSentinel);
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 800));
    try {
      _process.kill();
    } catch (_) {}
    for (final f in [_statusFile, _choiceFile].whereType<File>()) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }
}
