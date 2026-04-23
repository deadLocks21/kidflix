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
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .verifyOtp(_currentCode);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
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
    }
  }

  Future<void> _resend() async {
    await ref.read(sessionControllerProvider.notifier).resendOtp();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionControllerProvider);
    final phoneText = state is OtpRequested ? state.phone.e164 : '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              ref.read(sessionControllerProvider.notifier).backToPhoneEntry(),
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
