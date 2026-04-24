import 'package:flutter/material.dart';

/// Blocking UI displayed while a download is in flight but hasn't yet
/// reached the ready-to-play threshold.
class PlayerDownloadGate extends StatelessWidget {
  final String movieTitle;
  final int bytesReceived;
  final int? bytesTotal;
  final VoidCallback onCancel;

  const PlayerDownloadGate({
    super.key,
    required this.movieTitle,
    required this.bytesReceived,
    required this.onCancel,
    this.bytesTotal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = bytesTotal;
    final progress = total != null && total > 0 ? bytesReceived / total : null;

    final caption = total != null
        ? '${formatBytesMB(bytesReceived)} / ${formatBytesMB(total)}'
        : formatBytesMB(bytesReceived);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              movieTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 320,
              child: progress != null
                  ? LinearProgressIndicator(value: progress)
                  : const LinearProgressIndicator(),
            ),
            const SizedBox(height: 12),
            Text(caption, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onCancel, child: const Text('Annuler')),
          ],
        ),
      ),
    );
  }
}

/// Formats [bytes] as a megabytes string with 1 decimal place.
String formatBytesMB(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1)} MB';
}
