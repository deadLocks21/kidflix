import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/usecases/verify_management_pin.usecase.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';

/// PIN d'entrée du mode gestion : le code du profil principal.
/// Mécaniques calquées sur `ProfilePinPage` (TextField invisible, shake
/// animation sur PIN faux, auto-submit à 4 digits).
class ManagementPinPage extends ConsumerStatefulWidget {
  const ManagementPinPage({super.key});

  @override
  ConsumerState<ManagementPinPage> createState() => _ManagementPinPageState();
}

class _ManagementPinPageState extends ConsumerState<ManagementPinPage>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isVerifying = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
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
    setState(() {});
    if (_controller.text.length == _pinLength && !_isVerifying) {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _isVerifying = true);
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .verifyManagementPin(_controller.text);
    if (!mounted) return;
    setState(() => _isVerifying = false);
    switch (result) {
      case VerifyManagementPinSuccess():
        break;
      case VerifyManagementPinInvalid():
        await _shake.forward(from: 0);
        if (!mounted) return;
        _controller.clear();
        _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = _controller.text.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Code principal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref
              .read(sessionControllerProvider.notifier)
              .cancelManagementPinEntry(),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusNode.requestFocus,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text(
                  'Saisis le code du profil principal\npour gérer les profils',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 48),
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
                const SizedBox(height: 24),
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
                    const SizedBox(height: 24),
                    if (_isVerifying) const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
