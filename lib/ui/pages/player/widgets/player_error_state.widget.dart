import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/movie_download.dto.dart';

/// Full-surface error screen displayed when the download fails or is
/// cancelled before the ready-to-play threshold.
class PlayerErrorState extends StatelessWidget {
  final DownloadStatusDto status;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const PlayerErrorState({
    super.key,
    required this.status,
    required this.onRetry,
    required this.onBack,
    this.errorMessage,
  });

  String get _message {
    if (status == DownloadStatusDto.cancelled) {
      return 'Téléchargement annulé.';
    }
    return 'Impossible de télécharger le film.';
  }

  @override
  Widget build(BuildContext context) {
    final detail = errorMessage;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (detail != null && detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: onBack,
                  child: const Text('Retour'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
