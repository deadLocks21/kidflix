import 'package:flutter/material.dart';

/// Sole interactive control rendered when the kids lock is engaged.
/// Tapping it opens the unlock PIN dialog.
class UnlockButton extends StatelessWidget {
  final VoidCallback onTap;

  const UnlockButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.lock, color: Colors.white),
      tooltip: 'Déverrouiller',
      onPressed: onTap,
    );
  }
}
