import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kidflix/core/application/usecases/verify_management_pin.usecase.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';

/// Modal PIN dialog opened when the user taps the unlock button on a
/// locked player. Returns `true` when the entered PIN matches the
/// main profile's `pinHash`, `false` when the user cancels.
///
/// The dialog stays open on incorrect PIN — the caller never receives
/// a `false` until the user explicitly cancels.
Future<bool> showUnlockPinDialog(
  BuildContext context, {
  required Profile mainProfile,
  required ProfilePinService pinService,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _UnlockPinDialog(mainProfile: mainProfile, pinService: pinService),
  );
  return result ?? false;
}

class _UnlockPinDialog extends StatefulWidget {
  final Profile mainProfile;
  final ProfilePinService pinService;

  const _UnlockPinDialog({required this.mainProfile, required this.pinService});

  @override
  State<_UnlockPinDialog> createState() => _UnlockPinDialogState();
}

class _UnlockPinDialogState extends State<_UnlockPinDialog>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _shake;
  late final VerifyManagementPinUseCase _verify;
  bool _isVerifying = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _verify = VerifyManagementPinUseCase(widget.pinService);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      if (_showError && _controller.text.isNotEmpty) _showError = false;
    });
    if (_controller.text.length == _pinLength && !_isVerifying) {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _isVerifying = true);
    final result = await _verify.execute(
      mainProfile: widget.mainProfile,
      rawPin: _controller.text,
    );
    if (!mounted) return;
    setState(() => _isVerifying = false);
    switch (result) {
      case VerifyManagementPinSuccess():
        Navigator.of(context).pop(true);
      case VerifyManagementPinInvalid():
        await _shake.forward(from: 0);
        if (!mounted) return;
        setState(() {
          _showError = true;
          _controller.clear();
        });
        _focusNode.requestFocus();
    }
  }

  void _onCancel() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = _controller.text.length;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Code parent'),
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusNode.requestFocus,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Saisis le code du profil principal',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  final t = _shake.value;
                  final dx = t == 0 ? 0.0 : 8 * (1 - t) * (t < 0.5 ? 1 : -1);
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (i) {
                    final isFilled = i < filled;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 20,
                        height: 20,
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
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: _pinLength,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                  ),
                  style: const TextStyle(
                    color: Colors.transparent,
                    height: 0.01,
                  ),
                  cursorColor: Colors.transparent,
                  enableInteractiveSelection: false,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 24,
                child: _isVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _showError
                    ? Text(
                        'Code incorrect',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isVerifying ? null : _onCancel,
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
