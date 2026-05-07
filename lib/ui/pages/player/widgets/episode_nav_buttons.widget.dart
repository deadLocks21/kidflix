import 'package:flutter/material.dart';

/// Top-bar button to jump to the previous episode in the current
/// series rotation. Disabled (greyed out) when there is no previous.
class PreviousEpisodeButton extends StatelessWidget {
  final VoidCallback? onTap;

  const PreviousEpisodeButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.skip_previous_rounded,
        color: onTap == null ? Colors.white38 : Colors.white,
      ),
      tooltip: 'Épisode précédent',
      onPressed: onTap,
    );
  }
}

/// Top-bar button to jump to the next episode in the current series
/// rotation (or to a fresh shuffle pick). Disabled when there is no
/// candidate.
class NextEpisodeButton extends StatelessWidget {
  final VoidCallback? onTap;

  const NextEpisodeButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.skip_next_rounded,
        color: onTap == null ? Colors.white38 : Colors.white,
      ),
      tooltip: 'Épisode suivant',
      onPressed: onTap,
    );
  }
}

/// Top-bar button that opens the episode picker sheet.
class EpisodePickerButton extends StatelessWidget {
  final VoidCallback onTap;

  const EpisodePickerButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.playlist_play_rounded, color: Colors.white),
      tooltip: 'Liste des épisodes',
      onPressed: onTap,
    );
  }
}
