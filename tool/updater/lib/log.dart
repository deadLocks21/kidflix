import 'dart:io';

/// Logger best-effort : écrit dans un fichier (`<root>/updater.log`) ET sur la
/// sortie standard. Les lancements quotidiens se font fenêtre cachée (aucune
/// console visible), donc le fichier est la seule trace exploitable ; les
/// écritures stdout sont silencieuses mais inoffensives et protégées par un
/// try/catch au cas où aucun handle de console n'existe.
class Log {
  Log(this.file);

  /// Chemin du fichier de log, ou `null` tant que la racine d'install est
  /// inconnue (tout début du flux d'installation).
  String? file;

  void call(String message) {
    final line = '[${DateTime.now().toIso8601String()}] $message';
    final target = file;
    if (target != null) {
      try {
        File(target).writeAsStringSync('$line\n', mode: FileMode.append);
      } catch (_) {
        // Disque plein / permission : on n'empêche pas l'updater de tourner.
      }
    }
    try {
      stdout.writeln(line);
    } catch (_) {
      // Pas de console attachée (lancement caché) : ignoré.
    }
  }

  void error(String message, [Object? err, StackTrace? st]) {
    call('ERREUR: $message${err != null ? ' — $err' : ''}');
    if (st != null) call(st.toString());
  }
}
