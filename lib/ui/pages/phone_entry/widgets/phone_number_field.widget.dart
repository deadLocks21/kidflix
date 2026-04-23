import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text field numérique pour un numéro français (06 ou 07, 10 chiffres).
/// Affiche un feedback visuel (rouge / vert) en fonction de la validité.
class PhoneNumberField extends StatelessWidget {
  final TextEditingController controller;
  final bool isValid;
  final String? errorText;
  final void Function(String) onChanged;
  final VoidCallback? onSubmitted;

  const PhoneNumberField({
    super.key,
    required this.controller,
    required this.isValid,
    required this.onChanged,
    this.errorText,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 10,
      autofocus: true,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: 'Numéro de téléphone',
        hintText: '06XXXXXXXX',
        counterText: '',
        errorText: errorText,
        suffixIcon: controller.text.isEmpty
            ? null
            : Icon(
                isValid ? Icons.check_circle : Icons.error_outline,
                color: isValid ? Colors.green : Colors.red,
              ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
