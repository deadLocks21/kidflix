import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Réutilisable : affiche 4 indicateurs circulaires + un TextField invisible
/// qui capte la saisie clavier. Notifie le parent à chaque changement via
/// [onChanged] et laisse celui-ci orchestrer la soumission / reset.
class PinConfirmField extends StatefulWidget {
  final String label;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  static const int pinLength = 4;

  const PinConfirmField({
    super.key,
    required this.label,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<PinConfirmField> createState() => PinConfirmFieldState();
}

class PinConfirmFieldState extends State<PinConfirmField> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _controller.addListener(_emitChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_emitChange);
    _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _emitChange() {
    setState(() {});
    widget.onChanged(_controller.text);
  }

  /// Allows parent widgets (e.g. on submit feedback) to reset the field.
  void clear() {
    _controller.clear();
  }

  void requestFocus() => _focusNode.requestFocus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = _controller.text.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusNode.requestFocus,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(PinConfirmField.pinLength, (i) {
              final isFilled = i < filled;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(
          width: 1,
          height: 1,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: PinConfirmField.pinLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
            ),
            style: const TextStyle(color: Colors.transparent, height: 0.01),
            cursorColor: Colors.transparent,
            enableInteractiveSelection: false,
          ),
        ),
      ],
    );
  }
}
