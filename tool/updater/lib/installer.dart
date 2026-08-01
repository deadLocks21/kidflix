import 'dart:io';

import 'package:path/path.dart' as p;

import 'config.dart';
import 'download.dart';
import 'github.dart';
import 'layout.dart';
import 'links.dart';
import 'log.dart';
import 'progress.dart';
import 'shortcuts.dart';

/// Orchestration des trois flux : installation, mise à jour, lancement.
class Installer {
  Installer(this.layout, this.log);

  final Layout layout;
  final Log log;

  /// Première version de l'app embarquant le mode `--updating` (fenêtre de
  /// progression Flutter). On n'affiche le splash que si l'app DÉJÀ installée
  /// est >= à cette version : sinon elle ne connaît pas `--updating` et
  /// lancerait l'app complète au lieu de la fenêtre.
  static const _minAppVersionForSplash = '1.10.0';

  /// Première version de l'app embarquant le **prompt** Oui/Non/Ignorer
  /// (`--prompt`). En dessous, on retombe sur le splash de progression
  /// silencieux (>= [_minAppVersionForSplash]).
  static const _minAppVersionForPrompt = '1.10.2';

  String get _tmpDir => p.join(layout.root, '.tmp');

  // ── Installation neuve ─────────────────────────────────────────────────────

  /// Installe Kidflix dans la racine de [layout]. [launch] démarre l'app à la
  /// fin (cas du double-clic sur l'installateur).
  Future<void> install({bool launch = true}) async {
    log('Installation dans ${layout.root}');
    // Retour visuel : la 1ʳᵉ install via le `.app` (double-clic) n'a pas de
    // fenêtre → sans ça l'utilisateur a l'impression que « rien ne se passe ».
    // Un dialogue macOS (FIABLE, contrairement à une notification que macOS
    // filtre souvent), fermé dès que l'app se lance. macOS uniquement, best-effort.
    final feedback = await _startInstallFeedback();
    try {
      Directory(layout.versionsDir).createSync(recursive: true);
      Directory(layout.updaterDir).createSync(recursive: true);
      log.file ??= layout.logFile;

      final release = await fetchLatestRelease();
      final asset = release.appAsset;
      if (asset == null) {
        throw StateError(
          'Aucun asset pour cette plateforme dans ${release.tag}',
        );
      }

      await _installVersion(release.version, asset);
      swapCurrent(layout.currentLink, layout.versionDir(release.version), log);

      _relocateUpdater();
      Config(root: layout.root, installedVersion: release.version)
        ..lastCheck = DateTime.now().toIso8601String()
        ..save(layout);
      layout.writePointer();
      createShortcuts(layout, log);
      _cleanupTmp();

      log('Installation terminée : Kidflix ${release.version}');
      if (launch) launchApp();
    } finally {
      feedback?.kill(); // ferme le dialogue de progression
    }
  }

  // ── Mise à jour silencieuse ────────────────────────────────────────────────

  /// Vérifie GitHub et applique une éventuelle MAJ, en silence. Best-effort :
  /// toute erreur (réseau, etc.) est loggée mais non propagée, pour ne jamais
  /// empêcher le lancement de l'app.
  ///
  /// Si [showUi] et qu'une MAJ est trouvée, affiche une fenêtre de progression
  /// (rendue par l'app via `--updating`) PENDANT le téléchargement. Aucune
  /// fenêtre n'apparaît s'il n'y a rien à mettre à jour.
  Future<void> updateIfAvailable({bool showUi = false}) async {
    final config = Config.load(layout);
    if (config == null) {
      log.error('updateIfAvailable appelé sans installation');
      return;
    }
    ProgressWindow? ui;
    try {
      final release = await fetchLatestRelease();
      config.lastCheck = DateTime.now().toIso8601String();

      if (compareVersions(release.version, config.installedVersion) <= 0) {
        log('À jour (${config.installedVersion}).');
        config.save(layout);
        return;
      }

      // Version explicitement ignorée par l'utilisateur : on ne repropose que
      // pour une version strictement plus récente.
      final ignored = config.ignoredVersion;
      if (ignored != null && compareVersions(release.version, ignored) <= 0) {
        log('MAJ ${release.version} ignorée (choix utilisateur).');
        config.save(layout);
        return;
      }

      log('MAJ ${config.installedVersion} -> ${release.version}');
      final asset = release.appAsset;
      if (asset == null) {
        log.error('Pas d\'asset pour cette plateforme dans ${release.tag}');
        return;
      }

      // Capacités de l'app DÉJÀ installée. On se base sur la version RÉELLE
      // pointée par `current` (dossier versions/<v>), pas sur config.json :
      // ainsi un config.json bidouillé (test) ne fausse pas la décision.
      final appVersion = _installedVersionOnDisk(config);
      final canSplash =
          showUi && compareVersions(appVersion, _minAppVersionForSplash) >= 0;
      final canPrompt =
          showUi && compareVersions(appVersion, _minAppVersionForPrompt) >= 0;

      if (canPrompt) {
        ui = await ProgressWindow.startPrompt(layout, log, release.version);
        final choice = await ui?.waitForChoice();
        if (choice == UpdateChoice.later) {
          log('MAJ ${release.version} reportée (« plus tard »).');
          await ui?.close();
          ui = null;
          config.save(layout);
          return;
        }
        if (choice == UpdateChoice.skip) {
          log('MAJ ${release.version} ignorée (« ignorer cette version »).');
          config.ignoredVersion = release.version;
          await ui?.close();
          ui = null;
          config.save(layout);
          return;
        }
        // UpdateChoice.update (ou null si lancement KO) : on poursuit ; la
        // fenêtre est déjà passée en vue progression.
      } else if (canSplash) {
        ui = await ProgressWindow.startProgress(layout, log);
      }

      ui?.status('Téléchargement de la version ${release.version}…');
      await _installVersion(release.version, asset);

      ui?.status('Installation…');
      swapCurrent(layout.currentLink, layout.versionDir(release.version), log);

      config.installedVersion = release.version;
      config.ignoredVersion = null; // une MAJ effective lève tout « ignorer ».
      config.save(layout);

      ui?.status('Finalisation…');
      await _selfUpdateUpdater(release);

      // Ferme le splash AVANT de purger : la fenêtre tourne depuis l'ancienne
      // version, dont _pruneOldVersions supprime le dossier.
      await ui?.close();
      ui = null;

      _pruneOldVersions(keep: release.version);
      _cleanupTmp();

      // Après la bascule de `current`, pour que l'icône soit résolue sur la
      // nouvelle version. Sans ça, une entrée écrite par un updater antérieur
      // ne serait jamais corrigée.
      refreshShortcuts(layout, log);

      log('Mise à jour appliquée : ${release.version}');
    } catch (e, st) {
      log.error('Mise à jour ignorée', e, st);
    } finally {
      await ui?.close();
    }
  }

  // ── Lancement de l'app ─────────────────────────────────────────────────────

  void launchApp() {
    // macOS : lancer le bundle via `open` (LaunchServices) → l'app est ACTIVÉE
    // et sa fenêtre passe au premier plan. Exécuter le binaire interne en direct
    // la lance mais sans l'activer : on voit l'animation d'ouverture puis…
    // aucune fenêtre. (`open` rend la main aussitôt, l'app reste détachée.)
    if (Platform.isMacOS) {
      final app = p.join(layout.currentLink, 'kidflix.app');
      if (!Directory(app).existsSync()) {
        log.error('Bundle introuvable : $app');
        return;
      }
      log('Lancement : open $app');
      Process.runSync('open', [app]);
      return;
    }
    final exe = layout.appExecutable;
    if (!File(exe).existsSync()) {
      log.error('Exécutable introuvable : $exe');
      return;
    }
    log('Lancement : $exe');
    Process.start(
      exe,
      const [],
      mode: ProcessStartMode.detached,
      workingDirectory: layout.currentLink,
    );
  }

  // ── Détails ────────────────────────────────────────────────────────────────

  Future<void> _installVersion(String version, ReleaseAsset asset) async {
    final file = await downloadAsset(asset, _tmpDir, log);
    installAppArtifact(file, layout.versionDir(version), log);
  }

  /// Version réellement installée = nom du dossier vers lequel pointe
  /// `current` (`versions/<v>`). Reflète le binaire d'app effectif, contrairement
  /// à `config.json` (qui peut être édité à la main). Repli sur config si la
  /// résolution du lien échoue.
  String _installedVersionOnDisk(Config config) {
    try {
      final real = Directory(layout.currentLink).resolveSymbolicLinksSync();
      final name = p.basename(real);
      if (name.isNotEmpty) return name;
    } catch (_) {
      // Lien cassé / illisible : on retombe sur config.
    }
    return config.installedVersion;
  }

  /// Copie le binaire updater courant vers `<root>/updater/` (emplacement
  /// stable visé par les raccourcis). No-op s'il s'exécute déjà depuis là.
  ///
  /// Sur macOS, on NE copie PAS `resolvedExecutable` : voir
  /// [_relocatableBinary]. La copie peut hériter de la quarantaine → on la
  /// purge, sinon le lanceur `.app` local se ferait tuer par Gatekeeper en
  /// l'exécutant.
  void _relocateUpdater() {
    final src = _relocatableBinary(Platform.resolvedExecutable);
    final dst = layout.updaterExe;
    if (p.equals(src, dst)) return;
    File(src).copySync(dst);
    if (!Platform.isWindows) Process.runSync('chmod', ['+x', dst]);
    _stripQuarantine(dst);
    log('Updater relocalisé : $dst');
  }

  /// Met à jour le binaire updater lui-même à partir de l'asset de la release.
  /// Sous Windows on ne peut pas écraser un exe en cours d'exécution : on
  /// renomme l'ancien en `.old` (autorisé) puis on écrit le nouveau au nom
  /// définitif ; le `.old` est purgé au lancement suivant.
  ///
  /// Sur macOS l'asset est un `.app` zippé (notarisé + staplé) : on en extrait
  /// la copie relocalisable (cf. [_relocatableBinary]). Le téléchargement passe
  /// par curl (jamais de quarantaine), donc la copie s'exécute sans souci
  /// Gatekeeper.
  Future<void> _selfUpdateUpdater(Release release) async {
    final asset = release.updaterAsset;
    if (asset == null) return;
    try {
      final dl = await downloadAsset(asset, _tmpDir, log);
      final src = _updaterBinaryFromAsset(dl);
      final dst = layout.updaterExe;
      final old = File('$dst.old');
      if (old.existsSync()) old.deleteSync();
      if (File(dst).existsSync()) File(dst).renameSync(old.path);
      src.copySync(dst);
      if (!Platform.isWindows) Process.runSync('chmod', ['+x', dst]);
      _stripQuarantine(dst);
      log('Updater auto-mis à jour (${release.version})');
    } catch (e) {
      log.error('Auto-MAJ de l\'updater ignorée', e);
    }
  }

  /// Résout le binaire updater à partir de l'asset téléchargé.
  ///  - Windows/Linux : l'asset EST déjà le binaire.
  ///  - macOS : l'asset est un `.app` zippé → on l'extrait via `ditto` (préserve
  ///    la structure du bundle) et on renvoie la copie relocalisable du bundle.
  File _updaterBinaryFromAsset(File downloaded) {
    if (!Platform.isMacOS) return downloaded;
    final dir = Directory(p.join(_tmpDir, 'updater-app'));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final args = ['-x', '-k', downloaded.path, dir.path];
    final r = Process.runSync('ditto', args);
    if (r.exitCode != 0) {
      throw ProcessException(
        'ditto',
        args,
        (r.stderr as String?) ?? 'ditto a échoué',
        r.exitCode,
      );
    }
    final app = dir.listSync().whereType<Directory>().firstWhere(
      (d) => d.path.endsWith('.app'),
      orElse: () => throw StateError('Aucun .app dans l\'asset updater macOS'),
    );
    final files = Directory(p.join(app.path, 'Contents', 'MacOS'))
        .listSync()
        .whereType<File>()
        .toList();
    if (files.isEmpty) {
      throw StateError('Binaire introuvable dans ${app.path}');
    }
    return File(_relocatableBinary(files.first.path));
  }

  /// Supprime les anciens dossiers de versions, en gardant [keep].
  void _pruneOldVersions({required String keep}) {
    final dir = Directory(layout.versionsDir);
    if (!dir.existsSync()) return;
    for (final entry in dir.listSync()) {
      if (entry is Directory && p.basename(entry.path) != keep) {
        try {
          entry.deleteSync(recursive: true);
        } catch (e) {
          log.error('Purge de ${entry.path}', e);
        }
      }
    }
  }

  void _cleanupTmp() {
    final tmp = Directory(_tmpDir);
    if (tmp.existsSync()) {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    }
    // Purge un éventuel updater .old laissé par une auto-MAJ précédente.
    final old = File('${layout.updaterExe}.old');
    if (old.existsSync()) {
      try {
        old.deleteSync();
      } catch (_) {}
    }
  }
}

/// Nom de la copie relocalisable embarquée dans `Contents/Resources/` du `.app`
/// installateur (cf. le job `build-updater` du CI).
const _relocatableName = 'kidflix-updater';

/// Renvoie, pour [executable], le binaire qu'on peut copier AILLEURS et
/// exécuter.
///
/// Hors macOS : [executable] lui-même.
///
/// Sur macOS, PAS l'exécutable principal du `.app` : signer un bundle re-signe
/// son exécutable principal en y **scellant le hash de son `Info.plist`** (le
/// `Info.plist entries=N` de `codesign -dv`). Copié hors de `Contents/MacOS/`,
/// ce `../Info.plist` n'existe plus → signature invalide → le hardened runtime
/// tue le process au démarrage (SIGKILL / CODESIGNING), exactement comme
/// l'absence d'entitlement JIT. Le `.app` embarque donc une SECONDE copie du
/// binaire dans `Contents/Resources/`, signée en autonome (hors contexte de
/// bundle, donc sans `Info.plist` scellé) : c'est celle-là qui se relocalise.
///
/// Repli sur [executable] si la copie est absente : binaire nu Windows/Linux,
/// build local (`dart compile exe` sans `.app`), ou updater déjà relocalisé.
String _relocatableBinary(String executable) {
  if (!Platform.isMacOS) return executable;
  final macosDir = p.dirname(executable);
  if (p.basename(macosDir) != 'MacOS') return executable;
  final candidate = p.join(p.dirname(macosDir), 'Resources', _relocatableName);
  return File(candidate).existsSync() ? candidate : executable;
}

/// Retire l'attribut de quarantaine Gatekeeper d'un fichier (macOS uniquement,
/// best-effort). Utile pour une copie issue d'un `.app` téléchargé via le
/// navigateur : sans ça, l'exécuter la ferait tuer par Gatekeeper. `xattr -d`
/// renvoie non-zéro si l'attribut est absent — sans effet, on l'ignore.
void _stripQuarantine(String path) {
  if (!Platform.isMacOS) return;
  try {
    Process.runSync('xattr', ['-d', 'com.apple.quarantine', path]);
  } catch (_) {
    /* xattr indisponible : best-effort */
  }
}

/// Ouvre un dialogue macOS « Installation en cours… » et renvoie le process
/// `osascript` (à `kill()` dès l'app lancée). Retour visuel FIABLE : un dialogue
/// s'affiche toujours, là où une notification est souvent filtrée par macOS.
/// `giving up after` = filet si on oublie de le fermer. Best-effort : renvoie
/// null hors macOS ou si `osascript` est indisponible.
Future<Process?> _startInstallFeedback() async {
  if (!Platform.isMacOS) return null;
  try {
    final proc = await Process.start('osascript', [
      '-e',
      'display dialog "Installation de Kidflix en cours… (quelques secondes)" '
          'buttons {"OK"} default button 1 giving up after 120 '
          'with title "Kidflix" with icon note',
    ]);
    // On draine les flux pour ne pas bloquer, et on ignore le résultat.
    proc.stdout.drain<void>();
    proc.stderr.drain<void>();
    return proc;
  } catch (_) {
    return null;
  }
}
