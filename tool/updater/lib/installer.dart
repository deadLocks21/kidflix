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
    Directory(layout.versionsDir).createSync(recursive: true);
    Directory(layout.updaterDir).createSync(recursive: true);
    log.file ??= layout.logFile;

    final release = await fetchLatestRelease();
    final asset = release.appAsset;
    if (asset == null) {
      throw StateError('Aucun asset pour cette plateforme dans ${release.tag}');
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
  void _relocateUpdater() {
    final src = Platform.resolvedExecutable;
    final dst = layout.updaterExe;
    if (p.equals(src, dst)) return;
    File(src).copySync(dst);
    if (!Platform.isWindows) Process.runSync('chmod', ['+x', dst]);
    log('Updater relocalisé : $dst');
  }

  /// Met à jour le binaire updater lui-même à partir de l'asset de la release.
  /// Sous Windows on ne peut pas écraser un exe en cours d'exécution : on
  /// renomme l'ancien en `.old` (autorisé) puis on écrit le nouveau au nom
  /// définitif ; le `.old` est purgé au lancement suivant.
  Future<void> _selfUpdateUpdater(Release release) async {
    final asset = release.updaterAsset;
    if (asset == null) return;
    try {
      final dl = await downloadAsset(asset, _tmpDir, log);
      final dst = layout.updaterExe;
      final old = File('$dst.old');
      if (old.existsSync()) old.deleteSync();
      if (File(dst).existsSync()) File(dst).renameSync(old.path);
      dl.copySync(dst);
      if (!Platform.isWindows) Process.runSync('chmod', ['+x', dst]);
      log('Updater auto-mis à jour (${release.version})');
    } catch (e) {
      log.error('Auto-MAJ de l\'updater ignorée', e);
    }
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
