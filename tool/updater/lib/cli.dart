import 'dart:io';

import 'package:args/args.dart';

import 'config.dart';
import 'github.dart';
import 'installer.dart';
import 'layout.dart';
import 'log.dart';
import 'prompt.dart';

/// Point d'entrée logique de l'updater.
///
/// Sans argument :
///  - si Kidflix est déjà installé -> MAJ silencieuse + lancement (mode launch) ;
///  - sinon -> installation interactive (choix du dossier).
Future<int> runCli(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'install',
      negatable: false,
      help: 'Force une installation neuve.',
    )
    ..addFlag(
      'update',
      negatable: false,
      help: 'MAJ silencieuse, sans lancer l\'app.',
    )
    ..addFlag(
      'launch',
      negatable: false,
      help: 'MAJ silencieuse puis lance l\'app.',
    )
    ..addFlag(
      'check',
      negatable: false,
      help: 'Affiche version locale vs dernière dispo.',
    )
    ..addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Non-interactif (dossier par défaut).',
    )
    ..addOption(
      'dir',
      help: 'Dossier d\'installation (sinon demandé / défaut).',
    )
    ..addFlag(
      'ui',
      negatable: false,
      help: 'Affiche une fenêtre de progression si une MAJ est appliquée.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(parser.usage);
    return 64;
  }

  if (opts['help'] as bool) {
    stdout.writeln(
      'kidflix-updater — installe, met à jour et lance Kidflix.\n',
    );
    stdout.writeln(parser.usage);
    return 0;
  }

  final dirOpt = opts['dir'] as String?;
  final yes = opts['yes'] as bool;
  final showUi = opts['ui'] as bool;
  final existing = Layout.resolveExisting();

  // --check : diagnostic, ne modifie rien.
  if (opts['check'] as bool) {
    return _check(existing);
  }

  // Installation explicite, ou aucune install détectée -> flux installateur.
  final forceInstall = opts['install'] as bool;
  if (forceInstall ||
      (existing == null &&
          !(opts['update'] as bool) &&
          !(opts['launch'] as bool))) {
    return _install(dirOpt: dirOpt, yes: yes);
  }

  // À ce stade on a besoin d'une install existante.
  if (existing == null) {
    // --update / --launch sans install : on bascule en installation.
    return _install(dirOpt: dirOpt, yes: yes);
  }

  final installer = Installer(existing, Log(existing.logFile));

  if (opts['update'] as bool) {
    await installer.updateIfAvailable(showUi: showUi);
    return 0;
  }

  // Défaut & --launch : la fenêtre de progression est activée par défaut.
  // Elle n'apparaît de toute façon que si une MAJ est réellement appliquée
  // (et seulement sous Windows) -> démarrage silencieux conservé sinon. On ne
  // dépend donc PAS du flag --ui dans le raccourci : les installs existantes
  // en bénéficient dès que l'updater s'est auto-mis à jour, sans réécrire le
  // launch.vbs (qui n'est régénéré qu'à l'installation).
  await installer.updateIfAvailable(showUi: true);
  installer.launchApp();
  return 0;
}

Future<int> _install({String? dirOpt, required bool yes}) async {
  final defaultRoot = Layout.defaultRoot();
  final String root;
  if (dirOpt != null && dirOpt.trim().isNotEmpty) {
    root = dirOpt.trim();
  } else if (yes) {
    root = defaultRoot;
  } else {
    root = promptInstallDir(defaultRoot);
  }

  final layout = Layout(root);
  final log = Log(
    null,
  ); // fichier de log inconnu tant que la racine n'existe pas
  final installer = Installer(layout, log);
  try {
    await installer.install(launch: true);
    return 0;
  } catch (e, st) {
    log.error('Installation échouée', e, st);
    return 1;
  }
}

Future<int> _check(Layout? existing) async {
  if (existing == null) {
    stdout.writeln('Kidflix n\'est pas installé.');
    return 0;
  }
  final config = Config.load(existing)!;
  stdout.writeln('Installé    : ${config.installedVersion}');
  stdout.writeln('Racine      : ${existing.root}');
  try {
    final release = await fetchLatestRelease();
    final cmp = compareVersions(release.version, config.installedVersion);
    stdout.writeln('Dernière    : ${release.version}');
    stdout.writeln(
      cmp > 0 ? 'État        : MAJ disponible' : 'État        : à jour',
    );
  } catch (e) {
    stdout.writeln('Dernière    : (indisponible — $e)');
  }
  return 0;
}
