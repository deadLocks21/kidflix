import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';

/// Modal dialog exposed by the ⚙ icon on [PhoneEntryPage]. Lets the user
/// type, validate and persist the API base URL so they can pick a backend
/// provider at runtime — clearing the field switches the app back to its
/// built-in in-memory mode.
class BackendUrlDialog extends ConsumerStatefulWidget {
  const BackendUrlDialog({super.key});

  /// Convenience: opens the dialog as a modal route over [context].
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const BackendUrlDialog(),
    );
  }

  @override
  ConsumerState<BackendUrlDialog> createState() => _BackendUrlDialogState();
}

class _BackendUrlDialogState extends ConsumerState<BackendUrlDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(apiBaseUrlProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns `null` when [value] is valid (empty is allowed = in-memory
  /// mode); otherwise a localised error message to display.
  String? _validate(String value) {
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return 'URL invalide';
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'URL doit commencer par http:// ou https://';
    }
    if (uri.host.isEmpty) return 'URL invalide';
    return null;
  }

  bool get _canSave => _errorText == null && !_isSaving;

  Future<void> _save() async {
    final value = _controller.text.trim();
    final error = _validate(value);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    setState(() => _isSaving = true);
    await ref.read(apiBaseUrlProvider.notifier).update(value);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('URL du backend'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Saisis l\'URL du backend Kidflix. Laisse vide pour utiliser le mode hors-ligne intégré.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'URL',
              hintText: 'https://api.example.com',
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              final error = _validate(value.trim());
              if (error != _errorText) setState(() => _errorText = error);
            },
            onSubmitted: (_) => _canSave ? _save() : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
