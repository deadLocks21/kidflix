import 'package:flutter/material.dart';

/// Small pill-shaped badge displayed in the player overlay while a movie
/// or episode is still being downloaded.
///
/// Shows a percentage when [bytesTotal] is known, falls back to a
/// "received MB" label otherwise (chunked endpoints without
/// Content-Length).
class DownloadStatusBadge extends StatelessWidget {
  final int bytesReceived;
  final int? bytesTotal;

  const DownloadStatusBadge({
    super.key,
    required this.bytesReceived,
    this.bytesTotal,
  });

  @override
  Widget build(BuildContext context) {
    final total = bytesTotal;
    final label = (total != null && total > 0)
        ? 'Téléchargement ${((bytesReceived / total).clamp(0.0, 1.0) * 100).round()} %'
        : '${_formatMo(bytesReceived)} téléchargés';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.download, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
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
