import 'dart:io';

/// Demande le dossier d'installation à l'utilisateur, avec [defaultDir]
/// pré-rempli. Entrée vide => valeur par défaut. Utilisé UNIQUEMENT lors de la
/// première installation (la seule étape interactive : les lancements suivants
/// sont silencieux).
String promptInstallDir(String defaultDir) {
  stdout.writeln('Installation de Kidflix.');
  stdout.write('Dossier d\'installation [$defaultDir] : ');
  final line = stdin.readLineSync();
  final trimmed = line?.trim() ?? '';
  return trimmed.isEmpty ? defaultDir : trimmed;
}
