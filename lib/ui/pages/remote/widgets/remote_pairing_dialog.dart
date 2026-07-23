import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/domain/model/remote_device.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Asks for the six digits shown on [device] and exchanges them for a
/// durable token.
///
/// Pairing happens once per pair of devices — the token is remembered —
/// so the walk to the TV to read a code is a one-time cost, not a nightly
/// ritual.
Future<void> showRemotePairingDialog(
  BuildContext context,
  WidgetRef ref,
  RemoteDevice device,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _RemotePairingDialog(device: device),
  );
}

class _RemotePairingDialog extends ConsumerStatefulWidget {
  final RemoteDevice device;

  const _RemotePairingDialog({required this.device});

  @override
  ConsumerState<_RemotePairingDialog> createState() =>
      _RemotePairingDialogState();
}

class _RemotePairingDialogState extends ConsumerState<_RemotePairingDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Le code fait 6 chiffres.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await ref
        .read(remoteControlClientProvider)
        .pair(widget.device, code);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _submitting = false;
        _error = 'Code refusé. Vérifie le code affiché sur l’appareil.';
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: KidflixPalette.grey850,
      title: Text('Associer ${widget.device.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saisis le code à 6 chiffres affiché sur ${widget.device.name}, '
            'dans sa fenêtre Télécommande.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KidflixPalette.grey100),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_submitting,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '••••••',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Associer'),
        ),
      ],
    );
  }
}
