import 'package:flutter/material.dart';

/// Bottom-bar button that opens the subtitle-track selector sheet.
/// Disabled (greyed out) when [onTap] is `null` — used when the file has
/// no subtitle track at all. The icon flips to the filled variant when
/// subtitles are currently active to give a quick visual cue.
class SubtitleTrackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool active;

  const SubtitleTrackButton({super.key, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        active ? Icons.closed_caption : Icons.closed_caption_outlined,
        color: onTap == null ? Colors.white38 : Colors.white,
      ),
      tooltip: 'Sous-titres',
      onPressed: onTap,
    );
  }
}
