import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/verify_otp.usecase.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/otp_verify/widgets/otp_digit_field.widget.dart';
import 'package:kidflix/ui/pages/otp_verify/widgets/resend_button.widget.dart';

class OtpVerifyPage extends ConsumerStatefulWidget {
  const OtpVerifyPage({super.key});

  @override
  ConsumerState<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends ConsumerState<OtpVerifyPage> {
  static const int _digits = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_digits, (_) => TextEditingController());
    _focusNodes = List.generate(_digits, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentCode => _controllers.map((c) => c.text).join();

  void _clearAll() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  void _handleFilled(int index) {
    if (index < _digits - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (_currentCode.length == _digits) {
      _submit();
    }
  }

  void _handleEmpty(int index) {
    if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    // `catch` + `finally` et pas une remise à zéro après l'`await` : le
    // controller lit le device et écrit la session en stockage sécurisé
    // hors du usecase, donc hors de son filet à exceptions. Sans ça, un
    // échec de ces appels laisse l'écran figé sur son indicateur de
    // chargement — et `_submit` est appelé sans `await` depuis
    // `_handleFilled`, donc l'exception partirait dans le vide.
    VerifyOtpResult result;
    try {
      result = await ref
          .read(sessionControllerProvider.notifier)
          .verifyOtp(_currentCode);
    } catch (_) {
      result = const VerifyOtpFailure();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    if (!mounted) return;
    switch (result) {
      case VerifyOtpSuccess():
        // Redirection pilotée par le router.
        break;
      case VerifyOtpInvalidCode():
        _clearAll();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Code invalide')));
      case VerifyOtpExpired():
        _clearAll();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code expiré. Renvoie un nouveau code.'),
          ),
        );
      case VerifyOtpDeviceAlreadyRegistered():
        // Pas d'invitation à réessayer : l'appareil restera pris tant que
        // l'autre compte le détient.
        _clearAll();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cet appareil est déjà lié à un autre compte.'),
          ),
        );
      case VerifyOtpFailure():
        _clearAll();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connexion impossible. Vérifie ta connexion et réessaie.',
            ),
          ),
        );
    }
  }

  Future<void> _resend() async {
    // `ResendOtpUseCase` ne mappe que `unknown_phone_number` ; le reste
    // (réseau, 429, 5xx) remonte en exception jusqu'à `ResendButton`, qui
    // l'`await` sans protection. On la rattrape ici pour que l'échec se
    // voie au lieu de partir dans le vide.
    try {
      await ref.read(sessionControllerProvider.notifier).resendOtp();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Envoi impossible. Vérifie ta connexion et réessaie.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionControllerProvider);
    final phoneText = state is OtpRequested ? state.phone.e164 : '';
    // Session expirée : l'utilisateur n'a jamais tapé son numéro dans ce
    // flow, il n'y a donc pas d'écran de saisie derrière — on masque le
    // retour arrière plutôt que de le renvoyer sur une étape qu'il n'a
    // pas franchie.
    final expired = state is OtpRequested && state.sessionExpired;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification'),
        leading: expired
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => ref
                    .read(sessionControllerProvider.notifier)
                    .backToPhoneEntry(),
              ),
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
                if (expired) ...[
                  Text(
                    'Session expirée',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pour des raisons de sécurité, il faut te reconnecter. '
                    'On vient de t\'envoyer un nouveau code.',
                  ),
                  const SizedBox(height: 24),
                ] else
                  Text(
                    'Entre le code à 6 chiffres',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                const SizedBox(height: 8),
                Text('Envoyé au $phoneText'),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_digits, (i) {
                    return OtpDigitField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      autofocus: i == 0,
                      onFilled: () => _handleFilled(i),
                      onEmpty: () => _handleEmpty(i),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                if (_isSubmitting) const LinearProgressIndicator(),
                const SizedBox(height: 16),
                ResendButton(onResend: _resend),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
