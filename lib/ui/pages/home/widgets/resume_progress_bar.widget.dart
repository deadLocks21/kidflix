import 'package:flutter/material.dart';

/// Thin progress strip overlaid at the bottom of a card poster to show
/// how far the user got into a movie or episode.
///
/// Designed to sit inside a parent `ClipRRect` so it inherits the card's
/// rounded corners — does not clip itself.
class ResumeProgressBar extends StatelessWidget {
  final double progress;

  const ResumeProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: progress.clamp(0.0, 1.0),
      minHeight: 3,
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      valueColor: AlwaysStoppedAnimation<Color>(
        Colors.white.withValues(alpha: 0.9),
      ),
    );
  }
}
