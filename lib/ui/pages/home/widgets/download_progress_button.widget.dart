import 'package:flutter/material.dart';
import 'package:kidflix/ui/focus/kidflix_focus_zoom.widget.dart';

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
  /// Width of everything to the right of the icon.
  ///
  /// The other two download states adopt it for their label, so the
  /// button keeps one width from "Télécharger" through the progress bar
  /// to "Téléchargé". It used to resize under the pointer at each
  /// transition, which on an episode row shoved the neighbouring button
  /// sideways.
  static const double contentWidth = _barWidth + _gap + _readoutWidth;

  static const double _barWidth = 80;
  static const double _gap = 8;
  static const double _readoutWidth = 56;

  final int bytesReceived;
  final int? bytesTotal;
  final VoidCallback? onCancel;

  /// Icon-only rendering: a determinate ring around a stop glyph, the
  /// size of any other icon button. The readout moves to the tooltip.
  final bool compact;

  const DownloadProgressButton({
    super.key,
    required this.bytesReceived,
    this.bytesTotal,
    this.onCancel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = bytesTotal;
    final progress = (total != null && total > 0)
        ? (bytesReceived / total).clamp(0.0, 1.0)
        : null;
    final label = progress != null
        ? '${(progress * 100).round()} %'
        : _formatMo(bytesReceived);
    final cancellable = onCancel != null;
    if (compact) {
      return KidflixFocusZoom(
        child: IconButton(
          tooltip: cancellable
              ? 'Annuler le téléchargement ($label)'
              : 'Téléchargement en cours ($label)',
          onPressed: onCancel,
          icon: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: 22,
                // An indeterminate ring while the size is unknown — the
                // same reason the wide variant falls back to megabytes.
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2,
                ),
              ),
              Icon(cancellable ? Icons.close : Icons.download, size: 12),
            ],
          ),
        ),
      );
    }
    final button = KidflixFocusZoom(
      child: OutlinedButton(
        onPressed: onCancel,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cancellable ? Icons.close : Icons.download, size: 18),
            const SizedBox(width: _gap),
            SizedBox(
              width: _barWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: _gap),
            SizedBox(
              width: _readoutWidth,
              child: Text(label, textAlign: TextAlign.end),
            ),
          ],
        ),
      ),
    );
    if (!cancellable) return button;
    return Tooltip(message: 'Annuler le téléchargement', child: button);
  }

  static String _formatMo(int bytes) {
    if (bytes <= 0) return '0 Mo';
    final mo = bytes / (1024 * 1024);
    if (mo < 10) return '${mo.toStringAsFixed(1)} Mo';
    return '${mo.round()} Mo';
  }
}
