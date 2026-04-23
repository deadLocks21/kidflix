import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/usecases/change_main_profile_pin.usecase.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/profile_management/widgets/pin_confirm_field.widget.dart';

/// Changement du code du profil principal, double saisie obligatoire.
/// Une typo verrouillerait l'accès au mode gestion — on la rattrape en
/// demandant la même valeur deux fois avant toute mutation.
class ChangeMainPinPage extends ConsumerStatefulWidget {
  const ChangeMainPinPage({super.key});

  @override
  ConsumerState<ChangeMainPinPage> createState() => _ChangeMainPinPageState();
}

class _ChangeMainPinPageState extends ConsumerState<ChangeMainPinPage> {
  final _newKey = GlobalKey<PinConfirmFieldState>();
  final _confirmKey = GlobalKey<PinConfirmFieldState>();
  String _newPin = '';
  String _confirmPin = '';
  String? _error;
  bool _submitting = false;

  bool get _canSubmit =>
      _newPin.length == PinConfirmField.pinLength &&
      _confirmPin.length == PinConfirmField.pinLength &&
      !_submitting;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .changeMainProfilePin(newPin: _newPin, confirmPin: _confirmPin);
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case ChangeMainProfilePinSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code principal mis à jour')),
        );
        context.pop();
      case ChangeMainProfilePinMismatch():
        setState(() => _error = 'Les deux codes ne correspondent pas');
        _newKey.currentState?.clear();
        _confirmKey.currentState?.clear();
        _newKey.currentState?.requestFocus();
      case ChangeMainProfilePinInvalidPin():
        setState(() => _error = 'Le code doit faire 4 chiffres');
      case ChangeMainProfilePinNoMainProfile():
      case ChangeMainProfilePinInvalidState():
        setState(() => _error = 'Action impossible');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Changer le code principal'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const SizedBox(height: 16),
              PinConfirmField(
                key: _newKey,
                label: 'Nouveau code',
                autofocus: true,
                onChanged: (v) => setState(() => _newPin = v),
              ),
              const SizedBox(height: 32),
              PinConfirmField(
                key: _confirmKey,
                label: 'Confirmer le code',
                onChanged: (v) => setState(() => _confirmPin = v),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => context.pop(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _canSubmit ? _submit : null,
                      child: _submitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Valider'),
                    ),
                  ),
                ],
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
