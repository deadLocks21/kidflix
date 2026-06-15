import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/usecases/verify_management_pin.usecase.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/widgets/pin_pad.widget.dart';

/// PIN d'entrée du mode gestion : le code du profil principal. La saisie
/// passe par le pavé numérique partagé [PinPad] (pas le clavier système),
/// pour que la biométrie ne casse pas la saisie.
class ManagementPinPage extends ConsumerStatefulWidget {
  const ManagementPinPage({super.key});

  @override
  ConsumerState<ManagementPinPage> createState() => _ManagementPinPageState();
}

class _ManagementPinPageState extends ConsumerState<ManagementPinPage> {
  bool _biometricOffered = false;
  bool _biometricAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBiometric());
  }

  /// Resolves whether biometrics are offered for the management gate
  /// (governed by the main profile's opt-in) and, if so, auto-prompts
  /// once. Silent no-op otherwise.
  Future<void> _initBiometric() async {
    final offered = await ref
        .read(sessionControllerProvider.notifier)
        .isBiometricOfferedForManagement();
    if (!mounted) return;
    setState(() => _biometricOffered = offered);
    if (offered && !_biometricAttempted) {
      _biometricAttempted = true;
      await _promptBiometric();
    }
  }

  Future<void> _promptBiometric() async {
    await ref
        .read(sessionControllerProvider.notifier)
        .unlockManagementWithBiometrics();
  }

  Future<bool> _verify(String pin) async {
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .verifyManagementPin(pin);
    return result is VerifyManagementPinSuccess;
  }

  @override
  Widget build(BuildContext context) {
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
        child: PinPad(
          title: 'Saisis le code du profil principal\npour gérer les profils',
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
