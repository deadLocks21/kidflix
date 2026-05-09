import 'package:flutter/material.dart';

/// Bottom-bar button that opens the audio-track selector sheet.
/// Disabled (greyed out) when [onTap] is `null` — used when the file has
/// at most one audio track.
class AudioTrackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const AudioTrackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.audiotrack,
        color: onTap == null ? Colors.white38 : Colors.white,
      ),
      tooltip: 'Piste audio',
      onPressed: onTap,
    );
  }
}
