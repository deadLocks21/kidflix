import 'package:flutter/material.dart';
import 'package:kidflix/core/domain/model/remote_download.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Formats a byte count for a progress line.
///
/// Switches to GB past a gigabyte: films here run well over 1 000 MB, and
/// "1 400 Mo / 2 100 Mo" is harder to read at a glance than "1,4 / 2,1 Go".
String formatRemoteBytes(int bytes) {
  const mb = 1024 * 1024;
  const gb = 1024 * mb;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(1).replaceAll('.', ',')} Go';
  }
  return '${(bytes / mb).round()} Mo';
}

/// Tells the user what the host's download is doing, and offers a retry
/// when it stopped.
///
/// Without this the remote showed one spinner for "fetching", "stuck" and
/// "gave up" alike, and the only way to find out which was to walk to the
/// other device.
class RemoteDownloadStatusCard extends StatelessWidget {
  final RemoteDownloadSnapshot download;
  final VoidCallback onRetry;

  const RemoteDownloadStatusCard({
    super.key,
    required this.download,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (download.status == RemoteDownloadStatus.none ||
        download.status == RemoteDownloadStatus.complete) {
      // Nothing in flight and nothing wrong — the transport controls
      // already say everything there is to say.
      if (!download.interrupted) return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: download.canRetry
            ? KidflixPalette.red200.withValues(alpha: 0.18)
            : KidflixPalette.grey800,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: 16, color: _color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _headline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (download.canRetry)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Réessayer'),
                ),
            ],
          ),
          if (download.isRunning) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                // Null keeps the bar indeterminate rather than inventing
                // a percentage the host never reported.
                value: download.fraction,
                minHeight: 5,
                backgroundColor: KidflixPalette.grey600,
              ),
            ),
            const SizedBox(height: 6),
            Text(_progressLine, style: _subStyle(theme)),
          ],
          if (_detail case final detail?) ...[
            const SizedBox(height: 6),
            Text(detail, style: _subStyle(theme)),
          ],
        ],
      ),
    );
  }

  TextStyle? _subStyle(ThemeData theme) =>
      theme.textTheme.bodySmall?.copyWith(color: KidflixPalette.grey100);

  IconData get _icon {
    if (download.canRetry) return Icons.error_outline;
    return switch (download.status) {
      RemoteDownloadStatus.downloading ||
      RemoteDownloadStatus.readyToPlay => Icons.download_rounded,
      _ => Icons.check_circle_outline,
    };
  }

  Color get _color {
    if (download.canRetry) return KidflixPalette.red100;
    return download.isRunning ? KidflixPalette.blue200 : KidflixPalette.green;
  }

  String get _headline {
    if (download.interrupted) return 'Téléchargement interrompu';
    return switch (download.status) {
      RemoteDownloadStatus.downloading => 'Téléchargement en cours',
      // Playback has started but bytes are still arriving — worth saying,
      // because the seek bar is capped until they do.
      RemoteDownloadStatus.readyToPlay => 'Lecture lancée, suite en cours',
      RemoteDownloadStatus.failed => 'Téléchargement échoué',
      RemoteDownloadStatus.cancelled => 'Téléchargement annulé',
      _ => 'Téléchargé',
    };
  }

  String get _progressLine {
    final total = download.bytesTotal;
    final received = formatRemoteBytes(download.bytesReceived);
    if (total == null || total == 0) {
      // No Content-Length: report what has landed and nothing more.
      return '$received reçus';
    }
    final percent = ((download.fraction ?? 0) * 100).round();
    return '$percent % · $received / ${formatRemoteBytes(total)}';
  }

  /// Extra line under the headline: the failure reason, or why an
  /// interrupted download still plays.
  String? get _detail {
    if (download.interrupted) {
      return 'La lecture s’arrêtera à la fin de ce qui a été téléchargé.';
    }
    final message = download.errorMessage;
    if (message == null || message.isEmpty) return null;
    return message;
  }
}
