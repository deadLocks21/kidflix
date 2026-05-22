import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/change_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/clear_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/create_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/update_profile_metadata.usecase.dart';
import 'package:kidflix/core/domain/exceptions/invalid_profile_name.exception.dart';
import 'package:kidflix/core/domain/model/avatar_update.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/providers/avatars.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/avatars/avatar_random.dart';
import 'package:kidflix/ui/avatars/widgets/avatar_image.widget.dart';
import 'package:kidflix/ui/avatars/widgets/avatar_picker.widget.dart';
import 'package:kidflix/ui/pages/profile_management/widgets/age_category_picker.widget.dart';

/// Formulaire d'ajout / édition d'un profil non-principal.
///
/// - [profileId] null : mode création, un seul champ PIN optionnel
/// - [profileId] non-null : mode édition, PIN géré par 2 actions séparées
///   (Définir/Changer, Retirer)
///
/// L'édition d'un profil principal ne met à jour que son nom et sa
/// catégorie ; le PIN principal passe exclusivement par `ChangeMainPinPage`.
class ProfileFormPage extends ConsumerStatefulWidget {
  final String? profileId;

  const ProfileFormPage({super.key, this.profileId});

  @override
  ConsumerState<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends ConsumerState<ProfileFormPage> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  AgeCategory _ageCategory = AgeCategory.enfant;
  String? _nameError;
  String? _pinError;
  bool _prefilled = false;
  bool _submitting = false;

  /// Avatar id currently selected in the form (write-side).
  /// - Création : null tant que la catalogue n'a pas chargé ; auto-rempli
  ///   par un id random dès qu'elle est résolue.
  /// - Édition : valeur existante au prefill ; modifié si l'utilisateur
  ///   ouvre le picker et choisit un nouvel avatar.
  String? _avatarId;

  /// Vrai dès que l'utilisateur a explicitement choisi un avatar via le
  /// picker. Détermine si le PATCH d'édition envoie `AvatarSetTo` (vrai)
  /// ou `AvatarUnchanged` (faux).
  bool _avatarChanged = false;

  bool get _isEdit => widget.profileId != null;

  @override
  void initState() {
    super.initState();
    // Le hero affiche la lettre fallback (à partir du nom) tant qu'aucun
    // avatar n'est sélectionné. On rebuild à chaque frappe pour la voir
    // évoluer en temps réel.
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

  Profile? _existingProfile() {
    final state = ref.read(sessionControllerProvider);
    if (state is! ManagingProfiles) return null;
    for (final p in state.session.profiles) {
      if (p.id == widget.profileId) return p;
    }
    return null;
  }

  void _prefill(Profile profile) {
    _nameController.text = profile.name;
    _ageCategory = profile.ageCategory;
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
    setState(() {
      _nameError = null;
      _pinError = null;
      _submitting = true;
    });
    final name = _nameController.text;
    final rawPin = _pinController.text.isEmpty ? null : _pinController.text;
    if (_isEdit) {
      await _submitEdit(name, rawPin);
    } else {
      await _submitCreate(name, rawPin);
    }
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  Future<void> _submitCreate(String name, String? rawPin) async {
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .createProfile(
          name: name,
          ageCategory: _ageCategory,
          rawPin: rawPin,
          avatarId: _avatarId,
        );
    if (!mounted) return;
    switch (result) {
      case CreateProfileSuccess():
        context.pop();
      case CreateProfileInvalidName(:final reason):
        setState(() => _nameError = _nameErrorMessage(reason));
      case CreateProfileInvalidPin():
        setState(() => _pinError = 'Le code doit faire 4 chiffres');
      case CreateProfileInvalidState():
        _showSnack('État invalide');
    }
  }

  Future<void> _submitEdit(String name, String? rawPin) async {
    final id = widget.profileId!;
    final existing = _existingProfile();
    final avatarUpdate = _avatarChanged && _avatarId != null
        ? AvatarSetTo(_avatarId!)
        : const AvatarUnchanged();
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .updateProfileMetadata(
          profileId: id,
          name: name,
          ageCategory: _ageCategory,
          avatar: avatarUpdate,
        );
    if (!mounted) return;
    switch (result) {
      case UpdateProfileMetadataSuccess():
        break;
      case UpdateProfileMetadataInvalidName(:final reason):
        setState(() => _nameError = _nameErrorMessage(reason));
        return;
      case UpdateProfileMetadataUnknownProfile():
        _showSnack('Profil introuvable');
        return;
      case UpdateProfileMetadataInvalidState():
        _showSnack('État invalide');
        return;
    }

    // PIN side-effects in edit mode. The "Définir/Changer" field is only
    // submitted if the user typed a new value. The "Retirer" action is
    // handled via a dedicated button in the UI (see _clearPin).
    if (rawPin != null &&
        existing != null &&
        !existing.isMain &&
        rawPin.isNotEmpty) {
      final pinResult = await ref
          .read(sessionControllerProvider.notifier)
          .changeProfilePin(profileId: id, rawPin: rawPin);
      if (!mounted) return;
      switch (pinResult) {
        case ChangeProfilePinSuccess():
          break;
        case ChangeProfilePinInvalidPin():
          setState(() => _pinError = 'Le code doit faire 4 chiffres');
          return;
        case ChangeProfilePinUnknownProfile():
        case ChangeProfilePinInvalidState():
          _showSnack('Mise à jour du code échouée');
          return;
      }
    }

    if (mounted) context.pop();
  }

  Future<void> _clearPin() async {
    final id = widget.profileId;
    if (id == null) return;
    setState(() => _submitting = true);
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .clearProfilePin(profileId: id);
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
    final existing = _existingProfile();
    if (_isEdit && !_prefilled && existing != null) {
      _prefill(existing);
      _prefilled = true;
    }

    // En mode création, on tire un avatar random dès que la liste est
    // disponible. `ref.listen` évite de toucher au state pendant le build.
    if (!_isEdit) {
      ref.listen(avatarsListProvider, (previous, next) {
        next.whenData((options) {
          if (_avatarId == null && options.isNotEmpty) {
            setState(() {
              _avatarId = pickRandomAvatarId(options);
            });
          }
        });
      });
    }

    final isMain = existing?.isMain ?? false;
    final hasPin = existing?.pinHash != null;
    final title = _isEdit
        ? (isMain ? 'Profil principal' : 'Modifier le profil')
        : 'Ajouter un profil';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                    autofocus: !_isEdit,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: 'Nom',
                      border: const OutlineInputBorder(),
                      errorText: _nameError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AgeCategoryPicker(
                    value: _ageCategory,
                    onChanged: (c) => setState(() => _ageCategory = c),
                  ),
                  const SizedBox(height: 24),
                  if (!_isEdit || (!isMain && !hasPin))
                    _buildPinField(label: 'Code (optionnel, 4 chiffres)'),
                  if (_isEdit && !isMain && hasPin) ...[
                    _buildPinField(label: 'Nouveau code (4 chiffres)'),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _submitting ? null : _clearPin,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Retirer le code'),
                    ),
                  ],
                  if (_isEdit && isMain)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Pour changer le code du profil principal, utilise '
                        'l\'icône « clé » dans la liste.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
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
                        : const Text('Valider'),
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

/// Hero avatar in the form header: tap → opens the avatar picker. Affiche un
/// badge d'édition (crayon) en bas-droite pour signaler l'affordance.
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
