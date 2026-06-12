import 'dart:convert';
import 'dart:io';

/// Couche réseau déléguée à l'outil HTTP du système (curl / PowerShell / wget)
/// plutôt qu'à la pile TLS de Dart.
///
/// Pourquoi : sous Windows, le client TLS de Dart (BoringSSL) n'utilise PAS le
/// magasin de certificats Windows. Derrière un proxy d'entreprise qui
/// intercepte le TLS (Zscaler/Netskope…), la racine custom est présente dans
/// le magasin Windows mais inconnue de Dart -> `CERTIFICATE_VERIFY_FAILED`.
/// `curl.exe` (Schannel) et PowerShell utilisent le magasin Windows et les
/// réglages de proxy système : ils passent là où Dart échoue.
class HttpToolException implements Exception {
  HttpToolException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// GET d'une URL, corps renvoyé en texte.
String httpGetString(
  String url, {
  Map<String, String> headers = const {},
  int maxTimeSec = 20,
}) {
  // 1) curl (présent par défaut : Win10 1803+, macOS, la plupart des Linux).
  final curl = _tryRun('curl', [
    '-fsSL',
    '--max-time',
    '$maxTimeSec',
    for (final e in headers.entries) ...['-H', '${e.key}: ${e.value}'],
    url,
  ]);
  if (curl != null) {
    if (curl.exitCode == 0) return curl.stdout as String;
    throw HttpToolException('curl(${curl.exitCode}) ${_short(curl.stderr)}');
  }

  // 2) Repli : PowerShell (Windows) ou wget (*nix).
  if (Platform.isWindows) {
    final ps = _tryRun(
      'powershell',
      _psArgs(
        "(Invoke-WebRequest -UseBasicParsing -Uri '$url' -Headers ${_psHeaders(headers)} -TimeoutSec $maxTimeSec).Content",
      ),
    );
    if (ps != null) {
      if (ps.exitCode == 0) return ps.stdout as String;
      throw HttpToolException(
        'powershell(${ps.exitCode}) ${_short(ps.stderr)}',
      );
    }
  } else {
    final wget = _tryRun('wget', [
      '-qO-',
      '--timeout=$maxTimeSec',
      for (final e in headers.entries) '--header=${e.key}: ${e.value}',
      url,
    ]);
    if (wget != null) {
      if (wget.exitCode == 0) return wget.stdout as String;
      throw HttpToolException('wget(${wget.exitCode}) ${_short(wget.stderr)}');
    }
  }

  throw HttpToolException(
    'Aucun outil HTTP disponible (curl${Platform.isWindows ? '/powershell' : '/wget'}).',
  );
}

/// Télécharge une URL vers [outPath] (suit les redirections).
void httpDownload(
  String url,
  String outPath, {
  Map<String, String> headers = const {},
}) {
  final curl = _tryRun('curl', [
    '-fsSL',
    '-o',
    outPath,
    for (final e in headers.entries) ...['-H', '${e.key}: ${e.value}'],
    url,
  ]);
  if (curl != null) {
    if (curl.exitCode == 0) return;
    throw HttpToolException('curl(${curl.exitCode}) ${_short(curl.stderr)}');
  }

  if (Platform.isWindows) {
    final ps = _tryRun(
      'powershell',
      _psArgs(
        "Invoke-WebRequest -UseBasicParsing -Uri '$url' -OutFile '$outPath' -Headers ${_psHeaders(headers)}",
      ),
    );
    if (ps != null) {
      if (ps.exitCode == 0) return;
      throw HttpToolException(
        'powershell(${ps.exitCode}) ${_short(ps.stderr)}',
      );
    }
  } else {
    final wget = _tryRun('wget', [
      '-qO',
      outPath,
      for (final e in headers.entries) '--header=${e.key}: ${e.value}',
      url,
    ]);
    if (wget != null) {
      if (wget.exitCode == 0) return;
      throw HttpToolException('wget(${wget.exitCode}) ${_short(wget.stderr)}');
    }
  }

  throw HttpToolException(
    'Aucun outil HTTP disponible (curl${Platform.isWindows ? '/powershell' : '/wget'}).',
  );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Exécute [exe] ; renvoie `null` si l'exécutable est introuvable (PATH).
ProcessResult? _tryRun(String exe, List<String> args) {
  try {
    return Process.runSync(
      exe,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } on ProcessException {
    return null;
  }
}

/// Force TLS 1.2 et coupe la barre de progression (lente en PS 5.1).
List<String> _psArgs(String command) => [
  '-NoProfile',
  '-NonInteractive',
  '-Command',
  "\$ProgressPreference='SilentlyContinue'; "
      '[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; '
      '$command',
];

/// Construit un littéral hashtable PowerShell : `@{'K'='V';...}` (ou `@{}`).
String _psHeaders(Map<String, String> headers) {
  if (headers.isEmpty) return '@{}';
  final entries = headers.entries
      .map((e) => "'${e.key}'='${e.value}'")
      .join(';');
  return '@{$entries}';
}

String _short(Object? stderr) {
  final s = (stderr ?? '').toString().trim().replaceAll('\n', ' ');
  return s.length > 200 ? '${s.substring(0, 200)}…' : s;
}
