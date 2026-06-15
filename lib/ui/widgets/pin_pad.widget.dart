import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kidflix/ui/theme/app_colors.dart';

/// On-screen numeric PIN entry.
///
/// Uses a tappable keypad (plus physical-keyboard keys on desktop)
/// instead of the system soft keyboard. This is deliberate: a native
/// overlay — notably the biometric sheet — steals the IME and the soft
/// keyboard cannot be reliably brought back, which previously left the
/// user unable to type once biometrics were enabled. An on-screen keypad
/// is immune to that since it is plain widgets, always visible.
///
/// Layout: the title and the code dots sit at the top; the keypad is
/// pinned to the bottom of the page. When provided, [footer] (e.g. the
/// biometric button) takes the bottom-left key slot, to the left of `0`.
///
/// Shared by the profile-unlock and management gates.
class PinPad extends StatefulWidget {
  final String title;
  final int pinLength;

  /// Verifies [pin]. Return `true` on success (the host navigates away),
  /// `false` to play the shake animation and clear the field.
  final Future<bool> Function(String pin) onSubmit;

  /// Optional widget placed in the bottom-left key slot, left of `0`
  /// (e.g. a biometric button). Replaced by a spinner while verifying.
  final Widget? footer;

  const PinPad({
    super.key,
    required this.title,
    required this.onSubmit,
    this.pinLength = 4,
    this.footer,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  static const double _keySize = 72;

  final _focusNode = FocusNode();
  String _pin = '';
  bool _verifying = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _append(String digit) {
    if (_verifying || _pin.length >= widget.pinLength) return;
    setState(() => _pin += digit);
    if (_pin.length == widget.pinLength) _submit();
  }

  void _backspace() {
    if (_verifying || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _verifying = true);
    final ok = await widget.onSubmit(_pin);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (!ok) {
      await _shake.forward(from: 0);
      if (!mounted) return;
      setState(() => _pin = '');
    }
  }

  /// Physical-keyboard support (desktop): digits append, backspace
  /// deletes. A plain [Focus] never raises the soft keyboard on mobile.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch != null && ch.length == 1 && '0123456789'.contains(ch)) {
      _append(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The on-screen keypad only makes sense on touch platforms. On desktop
    // the user has a physical keyboard (handled by [_onKey]), so we hide
    // the keypad and show a typing hint instead.
    final platform = theme.platform;
    final showKeypad =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      // Pin the keypad to the bottom while keeping the title + dots at the
      // top; fall back to scrolling when the viewport is too short
      // (landscape) so nothing overflows.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Title + code dots, vertically centred in the space
                    // above the keypad.
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 32),
                              _dots(theme),
                              if (!showKeypad) ...[
                                const SizedBox(height: 28),
                                SizedBox(
                                  height: 26,
                                  child: _verifying
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                          ),
                                        )
                                      : Text(
                                          'Saisis ton code au clavier',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color:
                                                    context.appColors.grey100,
                                              ),
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Keypad pinned to the bottom — touch platforms only.
                    if (showKeypad)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: _keypad(theme),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dots(ThemeData theme) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = t == 0 ? 0.0 : 8 * (1 - t) * (t < 0.5 ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.pinLength, (i) {
          final filled = i < _pin.length;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? theme.colorScheme.primary : Colors.transparent,
                border: Border.all(color: theme.colorScheme.primary, width: 2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _keypad(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) _digitKey(theme, d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _bottomLeftSlot(theme),
            _digitKey(theme, '0'),
            _backspaceKey(theme),
          ],
        ),
      ],
    );
  }

  /// The slot to the left of `0`: a spinner while verifying, otherwise the
  /// optional [PinPad.footer] (biometric button), otherwise empty.
  Widget _bottomLeftSlot(ThemeData theme) {
    final Widget child;
    if (_verifying) {
      child = const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    } else if (widget.footer != null) {
      child = Center(child: widget.footer!);
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(width: _keySize, height: _keySize, child: child),
    );
  }

  Widget _digitKey(ThemeData theme, String digit) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: context.appColors.grey700,
        shape: CircleBorder(side: BorderSide(color: context.appColors.grey500)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _verifying ? null : () => _append(digit),
          child: SizedBox(
            width: _keySize,
            height: _keySize,
            child: Center(
              child: Text(
                digit,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _backspaceKey(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _verifying ? null : _backspace,
          child: SizedBox(
            width: _keySize,
            height: _keySize,
            child: Icon(
              Icons.backspace_outlined,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
