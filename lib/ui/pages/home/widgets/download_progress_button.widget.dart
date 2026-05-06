import 'package:flutter/material.dart';

/// `OutlinedButton` displaying a download-in-progress state.
/// Shows a thin linear bar plus a textual progress indicator:
/// * `XX %` when [bytesTotal] is known (`> 0`),
/// * `12.3 Mo` (received bytes) otherwise — many backends stream the
///   file without a `Content-Length` header, so a determinate
///   percentage is impossible. Falling back to "bytes received" still
///   gives the user feedback that the transfer is alive.
///
/// When [onCancel] is provided, the button becomes tappable and swaps
/// the leading icon to a close glyph — tapping cancels the in-flight
/// download.
class DownloadProgressButton extends StatelessWidget {
  final int bytesReceived;
  final int? bytesTotal;
  final VoidCallback? onCancel;

  const DownloadProgressButton({
    super.key,
    required this.bytesReceived,
    this.bytesTotal,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final total = bytesTotal;
    final progress = (total != null && total > 0)
        ? (bytesReceived / total).clamp(0.0, 1.0)
        : null;
    final label =
        progress != null ? '${(progress * 100).round()} %' : _formatMo(bytesReceived);
    final cancellable = onCancel != null;
    final button = OutlinedButton(
      onPressed: onCancel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cancellable ? Icons.close : Icons.download, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(label, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
    if (!cancellable) return button;
    return Tooltip(
      message: 'Annuler le téléchargement',
      child: button,
    );
  }

  static String _formatMo(int bytes) {
    if (bytes <= 0) return '0 Mo';
    final mo = bytes / (1024 * 1024);
    if (mo < 10) return '${mo.toStringAsFixed(1)} Mo';
    return '${mo.round()} Mo';
  }
}
