import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/change_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/clear_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/update_profile_metadata.usecase.dart';
import 'package:kidflix/core/domain/exceptions/invalid_profile_name.exception.dart';
import 'package:kidflix/core/domain/model/avatar_update.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/avatars/widgets/avatar_image.widget.dart';
import 'package:kidflix/ui/avatars/widgets/avatar_picker.widget.dart';

/// Page d'auto-édition du profil courant depuis Paramètres.
///
/// Différences avec [ProfileFormPage] (mode édition) :
/// - Travaille uniquement sur le profil actif (`ProfileSelected.profile`),
///   l'id n'est jamais passé en argument.
/// - Pas d'édition de la catégorie d'âge : un enfant ne doit pas pouvoir
///   se reclasser pour débloquer du contenu.
/// - Champ code unique pour tous les profils (le double-saisie main reste
///   réservé au flow `ChangeMainPinPage` accessible depuis « Gérer les
///   profils »).
/// - L'API exige côté backend `X-Profile-Id == main` pour
///   `PATCH /profiles/*` — cette restriction est en cours d'assouplissement
///   serveur (carve-out auto-édition). En attendant, les profils
///   non-principaux verront un `403` remonter en erreur générique.
class SelfProfileEditPage extends ConsumerStatefulWidget {
  const SelfProfileEditPage({super.key});

  @override
  ConsumerState<SelfProfileEditPage> createState() =>
      _SelfProfileEditPageState();
}

class _SelfProfileEditPageState extends ConsumerState<SelfProfileEditPage> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  String? _avatarId;
  bool _avatarChanged = false;
  String? _nameError;
  String? _pinError;
  bool _prefilled = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
  }

  void _handleNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Profile? _currentProfile() {
    final s = ref.read(sessionControllerProvider);
    return s is ProfileSelected ? s.profile : null;
  }

  void _prefill(Profile profile) {
    _nameController.text = profile.name;
    _avatarId = profile.avatarId;
    _avatarChanged = false;
  }

  Future<void> _pickAvatar() async {
    final picked = await showAvatarPicker(context, currentId: _avatarId);
    if (picked != null && mounted) {
      setState(() {
        _avatarId = picked;
        _avatarChanged = true;
      });
    }
  }

  Future<void> _submit() async {
    final profile = _currentProfile();
    if (profile == null) return;
    setState(() {
      _nameError = null;
      _pinError = null;
      _submitting = true;
    });

    final name = _nameController.text;
    final rawPin = _pinController.text;
    final avatarUpdate = _avatarChanged && _avatarId != null
        ? AvatarSetTo(_avatarId!)
        : const AvatarUnchanged();

    final controller = ref.read(sessionControllerProvider.notifier);
    final metaResult = await controller.updateProfileMetadata(
      profileId: profile.id,
      name: name,
      ageCategory: profile.ageCategory,
      avatar: avatarUpdate,
    );
    if (!mounted) return;
    switch (metaResult) {
      case UpdateProfileMetadataSuccess():
        break;
      case UpdateProfileMetadataInvalidName(:final reason):
        setState(() {
          _nameError = _nameErrorMessage(reason);
          _submitting = false;
        });
        return;
      case UpdateProfileMetadataUnknownProfile():
        _showSnack('Profil introuvable');
        setState(() => _submitting = false);
        return;
      case UpdateProfileMetadataInvalidState():
        _showSnack('État invalide');
        setState(() => _submitting = false);
        return;
    }

    if (rawPin.isNotEmpty) {
      final pinResult = await controller.changeProfilePin(
        profileId: profile.id,
        rawPin: rawPin,
      );
      if (!mounted) return;
      switch (pinResult) {
        case ChangeProfilePinSuccess():
          break;
        case ChangeProfilePinInvalidPin():
          setState(() {
            _pinError = 'Le code doit faire 4 chiffres';
            _submitting = false;
          });
          return;
        case ChangeProfilePinUnknownProfile():
        case ChangeProfilePinInvalidState():
          _showSnack('Mise à jour du code échouée');
          setState(() => _submitting = false);
          return;
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    context.pop();
  }

  Future<void> _clearPin() async {
    final profile = _currentProfile();
    if (profile == null) return;
    setState(() => _submitting = true);
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .clearProfilePin(profileId: profile.id);
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case ClearProfilePinSuccess():
        _pinController.clear();
        _showSnack('Code retiré');
      case ClearProfilePinCannotClearMain():
        _showSnack('Le code du profil principal ne peut pas être retiré');
      case ClearProfilePinUnknownProfile():
      case ClearProfilePinInvalidState():
        _showSnack('Impossible de retirer le code');
    }
  }

  String _nameErrorMessage(InvalidProfileNameReason reason) => switch (reason) {
    InvalidProfileNameReason.empty => 'Le nom ne peut pas être vide',
    InvalidProfileNameReason.tooLong => '30 caractères maximum',
  };

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(
      sessionControllerProvider.select(
        (s) => s is ProfileSelected ? s.profile : null,
      ),
    );
    if (profile == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (!_prefilled) {
      _prefill(profile);
      _prefilled = true;
    }
    final hasPin = profile.pinHash != null;
    final canClearPin = hasPin && !profile.isMain;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AvatarHero(
                    avatarId: _avatarId,
                    nameForFallback: _nameController.text,
                    onTap: _submitting ? null : _pickAvatar,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: 'Nom',
                      border: const OutlineInputBorder(),
                      errorText: _nameError,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPinField(
                    label: hasPin
                        ? 'Nouveau code (4 chiffres)'
                        : 'Code (optionnel, 4 chiffres)',
                  ),
                  if (canClearPin) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _submitting ? null : _clearPin,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Retirer le code'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinField({required String label}) => TextField(
    controller: _pinController,
    keyboardType: TextInputType.number,
    obscureText: true,
    maxLength: 4,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      errorText: _pinError,
      counterText: '',
    ),
  );
}

class _AvatarHero extends StatelessWidget {
  final String? avatarId;
  final String nameForFallback;
  final VoidCallback? onTap;

  const _AvatarHero({
    required this.avatarId,
    required this.nameForFallback,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = nameForFallback.isNotEmpty
        ? nameForFallback.characters.first.toUpperCase()
        : '?';
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.bottomRight,
          clipBehavior: Clip.none,
          children: [
            AvatarImage(
              avatarId: avatarId,
              fallbackInitial: initial,
              size: 144,
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              child: Icon(
                Icons.edit,
                size: 18,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
