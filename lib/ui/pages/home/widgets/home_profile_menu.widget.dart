import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/avatars/widgets/avatar_image.widget.dart';
import 'package:kidflix/ui/router/app_router.dart';

enum _HomeMenuAction { settings, switchProfile, manageProfiles }

/// Bouton avatar dans l'AppBar de la home : affiche le profil actif et
/// ouvre un menu déroulant avec Paramètres / Quitter le profil / Gérer
/// les profils.
class HomeProfileMenu extends ConsumerWidget {
  const HomeProfileMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    // Le widget n'est rendu que dans la home, atteinte uniquement quand
    // l'état est ProfileSelected — si jamais on est rendu en transition,
    // on dégrade vers une icône neutre plutôt que de crasher.
    if (session is! ProfileSelected) {
      return const SizedBox.shrink();
    }
    final profile = ProfileDto.fromDomain(session.profile);
    final initial = profile.name.isNotEmpty
        ? profile.name.characters.first.toUpperCase()
        : '?';

    return PopupMenuButton<_HomeMenuAction>(
      tooltip: 'Profil',
      position: PopupMenuPosition.under,
      onSelected: (action) => _onSelected(context, ref, action),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _HomeMenuAction.settings,
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Paramètres'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        if (profile.isMain)
          const PopupMenuItem(
            value: _HomeMenuAction.manageProfiles,
            child: ListTile(
              leading: Icon(Icons.manage_accounts_outlined),
              title: Text('Gérer les profils'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        const PopupMenuItem(
          value: _HomeMenuAction.switchProfile,
          child: ListTile(
            leading: Icon(Icons.switch_account),
            title: Text('Quitter le profil'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: AvatarImage(
          avatarId: profile.avatarId,
          fallbackInitial: initial,
          size: 36,
        ),
      ),
    );
  }

  void _onSelected(
    BuildContext context,
    WidgetRef ref,
    _HomeMenuAction action,
  ) {
    final controller = ref.read(sessionControllerProvider.notifier);
    switch (action) {
      case _HomeMenuAction.settings:
        context.push(AppRoutes.settings);
      case _HomeMenuAction.switchProfile:
        controller.deselectProfile();
      case _HomeMenuAction.manageProfiles:
        controller.enterManagementMode();
    }
  }
}
