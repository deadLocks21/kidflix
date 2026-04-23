import 'dart:async';

import 'package:flutter/material.dart';

/// Bouton "Renvoyer le code" avec cooldown de 60s. Pendant le cooldown,
/// le bouton est désactivé et affiche le temps restant.
class ResendButton extends StatefulWidget {
  final Future<void> Function() onResend;
  final Duration cooldown;

  const ResendButton({
    super.key,
    required this.onResend,
    this.cooldown = const Duration(seconds: 60),
  });

  @override
  State<ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<ResendButton> {
  Timer? _timer;
  int _remaining = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await widget.onResend();
    if (!mounted) return;
    setState(() => _remaining = widget.cooldown.inSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _remaining--;
        if (_remaining <= 0) t.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _remaining > 0;
    return TextButton(
      onPressed: disabled ? null : _handleTap,
      child: Text(
        disabled ? 'Renvoyer le code (${_remaining}s)' : 'Renvoyer le code',
      ),
    );
  }
}
