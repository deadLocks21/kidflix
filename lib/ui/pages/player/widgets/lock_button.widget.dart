import 'package:flutter/material.dart';

/// Toggle that engages the kids lock from the player's bottom button
/// bar. Open padlock icon, white tint to match the other
/// `MaterialVideoControls` buttons.
class LockButton extends StatelessWidget {
  final VoidCallback onTap;

  const LockButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.lock_outline, color: Colors.white),
      tooltip: 'Verrouiller',
      onPressed: onTap,
    );
  }
}
