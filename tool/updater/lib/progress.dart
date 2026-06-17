import 'dart:io';

import 'package:path/path.dart' as p;

import 'layout.dart';
import 'log.dart';

/// Fenêtre de progression native (Windows uniquement), affichée pendant qu'une
/// mise à jour se télécharge/installe — et seulement dans ce cas.
///
/// Implémentation : un petit formulaire WinForms piloté par PowerShell, lancé
/// **totalement caché via un wrapper VBS** (window style 0 dès la création, donc
/// aucun flash de console). Comme le formulaire hérite alors du flag « caché »,
/// le script le **force visible** lui-même (`ShowWindow`/`SetForegroundWindow`).
///
/// Communication par fichier d'état : l'updater y écrit le libellé de l'étape,
/// puis le sentinel `__DONE__` que le formulaire détecte pour se fermer.
///
/// Best-effort : si quoi que ce soit échoue (ou hors Windows), la MAJ se
/// poursuit sans IHM. Les erreurs runtime du script vont dans
/// `progress-error.log` à côté du fichier d'état.
class ProgressWindow {
  ProgressWindow._(this._statusFile, this._tempFiles)
    : _shown = Stopwatch()..start();

  final File _statusFile;
  final List<File> _tempFiles;
  final Stopwatch _shown;

  static const _doneSentinel = '__DONE__';

  /// Durée d'affichage minimale, pour qu'une MAJ rapide ne fasse pas juste
  /// « flasher » la fenêtre.
  static const _minDisplay = Duration(milliseconds: 1200);

  static Future<ProgressWindow?> start(Layout layout, Log log) async {
    if (!Platform.isWindows) return null;
    try {
      final statusFile = File(p.join(layout.root, '.update-status'))
        ..writeAsStringSync('Préparation…');
      // BOM UTF-8 : PowerShell 5.1 lit sinon le script en ANSI -> accents KO.
      final bom = String.fromCharCode(0xFEFF);
      final scriptFile = File(p.join(layout.root, '.progress.ps1'))
        ..writeAsStringSync('$bom$_psBody');

      // VBS qui lance PowerShell totalement caché (window 0) : aucun terminal.
      final vbsFile = File(p.join(layout.root, '.progress.vbs'))
        ..writeAsStringSync(
          'CreateObject("WScript.Shell").Run '
          '"powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden '
          '-File ""${scriptFile.path}"" -StatusFile ""${statusFile.path}""", '
          '0, False',
        );

      // wscript lance le VBS puis rend la main aussitôt ; le formulaire se
      // ferme via le sentinel `__DONE__` (pas besoin de tuer le process).
      await Process.start('wscript', [
        vbsFile.path,
      ], mode: ProcessStartMode.detached);
      return ProgressWindow._(statusFile, [scriptFile, vbsFile, statusFile]);
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

  /// Demande la fermeture du formulaire et nettoie les fichiers temporaires.
  Future<void> close() async {
    // Garantit une durée d'affichage minimale (MAJ très rapide).
    final remaining = _minDisplay - _shown.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

    try {
      _statusFile.writeAsStringSync(_doneSentinel);
    } catch (_) {}
    // Laisse le formulaire lire le sentinel (poll 200 ms) et se fermer avant de
    // supprimer les fichiers qu'il lit.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    for (final f in _tempFiles) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  /// Corps du script WinForms. Le titre est codé en dur (accents fiables grâce
  /// au BOM) ; les libellés d'étape arrivent via le fichier d'état, relu en
  /// UTF-8.
  static const _psBody = r'''
param([string]$StatusFile)
$errLog = Join-Path (Split-Path -Parent $StatusFile) 'progress-error.log'
try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  Add-Type -Name Win -Namespace Native -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);'

  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'Kidflix'
  $form.FormBorderStyle = 'FixedDialog'
  $form.StartPosition = 'CenterScreen'
  $form.ClientSize = New-Object System.Drawing.Size(420, 130)
  $form.ControlBox = $false
  $form.MinimizeBox = $false
  $form.MaximizeBox = $false
  $form.TopMost = $true

  $title = New-Object System.Windows.Forms.Label
  $title.Text = 'Mise à jour de Kidflix'
  $title.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
  $title.AutoSize = $true
  $title.Location = New-Object System.Drawing.Point(20, 18)
  $form.Controls.Add($title)

  $status = New-Object System.Windows.Forms.Label
  $status.Text = 'Préparation…'
  $status.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  $status.AutoSize = $true
  $status.Location = New-Object System.Drawing.Point(20, 52)
  $form.Controls.Add($status)

  $bar = New-Object System.Windows.Forms.ProgressBar
  $bar.Style = 'Marquee'
  $bar.MarqueeAnimationSpeed = 30
  $bar.Location = New-Object System.Drawing.Point(20, 82)
  $bar.Size = New-Object System.Drawing.Size(380, 22)
  $form.Controls.Add($bar)

  # PowerShell est lancé caché -> le formulaire hérite de SW_HIDE. On le force
  # visible dès que son handle existe (timer one-shot après démarrage du loop).
  $showTimer = New-Object System.Windows.Forms.Timer
  $showTimer.Interval = 50
  $showTimer.Add_Tick({
    $showTimer.Stop()
    [Native.Win]::ShowWindow($form.Handle, 5) | Out-Null   # SW_SHOW
    [Native.Win]::SetForegroundWindow($form.Handle) | Out-Null
  })
  $showTimer.Start()

  $timer = New-Object System.Windows.Forms.Timer
  $timer.Interval = 200
  $timer.Add_Tick({
    try {
      if (Test-Path $StatusFile) {
        $txt = [System.IO.File]::ReadAllText($StatusFile, [System.Text.Encoding]::UTF8)
        if ($txt -eq '__DONE__') { $timer.Stop(); $form.Close() }
        elseif ($txt) { $status.Text = $txt }
      }
    } catch { }
  })
  $timer.Start()

  [void]$form.ShowDialog()
} catch {
  $_ | Out-File -FilePath $errLog -Encoding UTF8
}
''';
}
