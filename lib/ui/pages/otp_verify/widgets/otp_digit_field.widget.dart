import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Champ de saisie d'un seul chiffre d'un code OTP. Passe le focus au
/// champ suivant quand un chiffre est saisi, au précédent quand le champ
/// est vidé.
class OtpDigitField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback? onFilled;
  final VoidCallback? onEmpty;

  const OtpDigitField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.autofocus = false,
    this.onFilled,
    this.onEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: Theme.of(context).textTheme.headlineSmall,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        ),
        onChanged: (value) {
          if (value.isEmpty) {
            onEmpty?.call();
          } else {
            onFilled?.call();
          }
        },
      ),
    );
  }
}
