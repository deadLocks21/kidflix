import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/usecases/request_otp.usecase.dart';
import 'package:kidflix/core/domain/exceptions/invalid_phone_number.exception.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/phone_entry/widgets/backend_url_dialog.widget.dart';
import 'package:kidflix/ui/pages/phone_entry/widgets/phone_number_field.widget.dart';

class PhoneEntryPage extends ConsumerStatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  ConsumerState<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends ConsumerState<PhoneEntryPage> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid {
    try {
      PhoneNumber.parse(_controller.text);
      return true;
    } on InvalidPhoneNumberException {
      return false;
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });
    final RequestOtpResult result;
    try {
      result = await ref
          .read(sessionControllerProvider.notifier)
          .requestOtp(_controller.text);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    if (!mounted) return;
    switch (result) {
      case RequestOtpSuccess():
        // La redirection est prise en charge par go_router.
        break;
      case RequestOtpInvalidPhone():
        setState(() => _errorText = 'Numéro invalide (06 ou 07, 10 chiffres)');
      case RequestOtpUnknownPhone():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Numéro inconnu. Contactez l'admin.")),
        );
      case RequestOtpFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connexion impossible. Vérifie ta connexion et réessaie.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'URL du backend',
            onPressed: () => BackendUrlDialog.show(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Identifie-toi',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nous allons envoyer un code de vérification à 6 chiffres sur ton téléphone.',
                ),
                const SizedBox(height: 24),
                PhoneNumberField(
                  controller: _controller,
                  isValid: _isValid,
                  errorText: _errorText,
                  onChanged: (_) => setState(() {
                    if (_errorText != null) _errorText = null;
                  }),
                  onSubmitted: _isValid ? _submit : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isValid && !_isSubmitting ? _submit : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Envoyer le code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
