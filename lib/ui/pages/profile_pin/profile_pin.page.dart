import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/verify_profile_pin.usecase.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/widgets/pin_pad.widget.dart';

class ProfilePinPage extends ConsumerStatefulWidget {
  const ProfilePinPage({super.key});

  @override
  ConsumerState<ProfilePinPage> createState() => _ProfilePinPageState();
}

class _ProfilePinPageState extends ConsumerState<ProfilePinPage> {
  static const int _pinLength = 4;
  bool _biometricOffered = false;
  bool _biometricAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBiometric());
  }

  /// Resolves whether biometrics are offered for this profile and, if so,
  /// auto-prompts the OS sheet once. Silent no-op when not offered.
  Future<void> _initBiometric() async {
    final offered = await ref
        .read(sessionControllerProvider.notifier)
        .isBiometricOfferedForCurrentUnlock();
    if (!mounted) return;
    setState(() => _biometricOffered = offered);
    if (offered && !_biometricAttempted) {
      _biometricAttempted = true;
      await _promptBiometric();
    }
  }

  Future<void> _promptBiometric() async {
    // On success the router redirects away; on failure/cancel the keypad
    // stays visible — nothing to restore.
    await ref
        .read(sessionControllerProvider.notifier)
        .unlockCurrentProfileWithBiometrics();
  }

  Future<bool> _verify(String pin) async {
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .verifyPin(pin);
    return result is VerifyProfilePinSuccess;
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(
      sessionControllerProvider.select(
        (s) => s is PinRequired ? s.profile.name : '',
      ),
    );
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
        child: PinPad(
          title: 'Entre le code à $_pinLength chiffres',
          pinLength: _pinLength,
          onSubmit: _verify,
          footer: _biometricOffered
              ? IconButton.filledTonal(
                  onPressed: _promptBiometric,
                  icon: const Icon(Icons.fingerprint),
                  iconSize: 40,
                  tooltip: 'Utiliser la biométrie',
                )
              : null,
        ),
      ),
    );
  }
}
