import 'package:flutter/material.dart';

/// Disabled `OutlinedButton` displaying a download-in-progress state.
/// Shows a thin linear bar plus a textual progress indicator:
/// * `XX %` when [bytesTotal] is known (`> 0`),
/// * `12.3 Mo` (received bytes) otherwise — many backends stream the
///   file without a `Content-Length` header, so a determinate
///   percentage is impossible. Falling back to "bytes received" still
///   gives the user feedback that the transfer is alive.
class DownloadProgressButton extends StatelessWidget {
  final int bytesReceived;
  final int? bytesTotal;

  const DownloadProgressButton({
    super.key,
    required this.bytesReceived,
    this.bytesTotal,
  });

  @override
  Widget build(BuildContext context) {
    final total = bytesTotal;
    final progress = (total != null && total > 0)
        ? (bytesReceived / total).clamp(0.0, 1.0)
        : null;
    final label =
        progress != null ? '${(progress * 100).round()} %' : _formatMo(bytesReceived);
    return OutlinedButton(
      onPressed: null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.download, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
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
  }

  static String _formatMo(int bytes) {
    if (bytes <= 0) return '0 Mo';
    final mo = bytes / (1024 * 1024);
    if (mo < 10) return '${mo.toStringAsFixed(1)} Mo';
    return '${mo.round()} Mo';
  }
}
