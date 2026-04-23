import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/verify_profile_pin.usecase.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';

class ProfilePinPage extends ConsumerStatefulWidget {
  const ProfilePinPage({super.key});

  @override
  ConsumerState<ProfilePinPage> createState() => _ProfilePinPageState();
}

class _ProfilePinPageState extends ConsumerState<ProfilePinPage>
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
        .verifyPin(_controller.text);
    if (!mounted) return;
    setState(() => _isVerifying = false);
    switch (result) {
      case VerifyProfilePinSuccess():
        break;
      case VerifyProfilePinInvalid():
        await _shake.forward(from: 0);
        if (!mounted) return;
        _controller.clear();
        _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionControllerProvider);
    final name = state is PinRequired ? state.profile.name : '';
    final pinLength = _controller.text.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('PIN de $name'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              ref.read(sessionControllerProvider.notifier).cancelPinEntry(),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusNode.requestFocus,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Entre le code à $_pinLength chiffres',
                  style: Theme.of(context).textTheme.headlineSmall,
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
                      final filled = i < pinLength;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
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
                const SizedBox(height: 24),
                if (_isVerifying) const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
