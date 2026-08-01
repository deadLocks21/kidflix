import 'dart:io';

/// Demande le dossier d'installation à l'utilisateur, avec [defaultDir]
/// pré-rempli. Entrée vide => valeur par défaut. Utilisé UNIQUEMENT lors de la
/// première installation (la seule étape interactive : les lancements suivants
/// sont silencieux).
///
/// Sans terminal (ex. double-clic sur le `.app` lancé par le Finder), on ne
/// prompte pas : `stdin.readLineSync()` y échoue et ferait planter l'updater
/// AVANT toute install. On retombe alors silencieusement sur [defaultDir].
String promptInstallDir(String defaultDir) {
  if (!stdin.hasTerminal) return defaultDir;
  stdout.writeln('Installation de Kidflix.');
  stdout.write('Dossier d\'installation [$defaultDir] : ');
  String? line;
  try {
    line = stdin.readLineSync();
  } catch (_) {
    return defaultDir; // stdin illisible : défaut
  }
  final trimmed = line?.trim() ?? '';
  return trimmed.isEmpty ? defaultDir : trimmed;
}
