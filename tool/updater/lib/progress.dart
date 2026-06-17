import 'dart:io';

import 'package:path/path.dart' as p;

import 'layout.dart';
import 'log.dart';

/// Fenêtre de progression native (Windows uniquement), affichée pendant qu'une
/// mise à jour se télécharge/installe — et seulement dans ce cas.
///
/// Implémentée via une petite IHM PowerShell/WinForms lancée en processus
/// séparé. La communication se fait par un fichier d'état que le formulaire
/// relit en boucle : l'updater y écrit le libellé de l'étape courante, puis un
/// sentinel `__DONE__` pour demander la fermeture.
///
/// Best-effort : si PowerShell échoue ou qu'on n'est pas sous Windows, la MAJ
/// se poursuit sans IHM (jamais bloquée par l'affichage).
class ProgressWindow {
  ProgressWindow._(this._process, this._statusFile, this._scriptFile)
    : _shown = Stopwatch()..start();

  final Process _process;
  final File _statusFile;
  final File _scriptFile;
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

      // PAS de `-WindowStyle Hidden` : ce flag pose SW_HIDE dans le STARTUPINFO,
      // dont WinForms hérite pour la 1re fenêtre -> le formulaire ne s'affiche
      // jamais. On lance donc en style normal et le script cache lui-même sa
      // console (P/Invoke ShowWindow), ce qui n'affecte pas le formulaire.
      final process = await Process.start('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
        '-StatusFile',
        statusFile.path,
      ], mode: ProcessStartMode.detached);
      return ProgressWindow._(process, statusFile, scriptFile);
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
    // Laisse le formulaire lire le sentinel et se fermer en douceur.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      _process.kill();
    } catch (_) {}
    for (final f in [_scriptFile, _statusFile]) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  /// Corps du script WinForms. Le titre est codé en dur (accents fiables grâce
  /// au BOM) ; les libellés d'étape arrivent via le fichier d'état, relu en
  /// UTF-8. Toute erreur runtime est écrite dans `progress-error.log` à côté du
  /// fichier d'état, pour diagnostic.
  static const _psBody = r'''
param([string]$StatusFile)
$errLog = Join-Path (Split-Path -Parent $StatusFile) 'progress-error.log'
try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  # Cache la console de CE process (lancé en style normal, cf. commentaire Dart).
  Add-Type -Name Win -Namespace Native -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
  [Native.Win]::ShowWindow([Native.Win]::GetConsoleWindow(), 0) | Out-Null

  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'Kidflix'
  $form.FormBorderStyle = 'FixedDialog'
  $form.StartPosition = 'CenterScreen'
  $form.ClientSize = New-Object System.Drawing.Size(420, 130)
  $form.ControlBox = $false
  $form.MinimizeBox = $false
  $form.MaximizeBox = $false
  $form.TopMost = $true
  $form.Add_Shown({ $form.Activate(); $form.BringToFront() })

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
