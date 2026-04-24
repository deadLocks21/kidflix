import 'package:flutter/material.dart';
import 'package:kidflix/shared/duration_format.dart';

/// User choice returned by [showResumeDialog].
enum ResumeChoice { resume, restart }

/// Non-dismissible dialog asking the user whether to resume playback
/// from a stored position or restart from zero.
Future<ResumeChoice?> showResumeDialog(
  BuildContext context,
  Duration position,
) {
  return showDialog<ResumeChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Reprendre la lecture ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ResumeChoice.restart),
            child: const Text('Recommencer'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ResumeChoice.resume),
            child: Text('Reprendre à ${formatDurationHuman(position)}'),
          ),
        ],
      ),
    ),
  );
}
