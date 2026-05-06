import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/delete_profile.usecase.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/profile_management/widgets/profile_management_tile.widget.dart';
import 'package:kidflix/ui/router/app_router.dart';

/// Liste de gestion des profils : tiles avec actions (éditer, supprimer,
/// changer le code principal). Bouton flottant pour ajouter un profil,
/// bouton AppBar "Terminer" pour sortir du mode gestion.
class ManagementListPage extends ConsumerWidget {
  const ManagementListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    final session = state is ManagingProfiles ? state.session : null;
    final profiles =
        session?.profiles.map(ProfileDto.fromDomain).toList(growable: false) ??
        const <ProfileDto>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les profils'),
        actions: [
          TextButton(
            onPressed: () => ref
                .read(sessionControllerProvider.notifier)
                .exitManagementMode(),
            child: const Text('Terminer'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...profiles.map(
                  (dto) => ProfileManagementTile(
                    key: ValueKey(dto.id),
                    profile: dto,
                    onEdit: () =>
                        context.push('/profiles/manage/${dto.id}/edit'),
                    onDelete: () => _confirmAndDelete(context, ref, dto),
                    onChangeMainPin: () =>
                        context.push(AppRoutes.manageMainPin),
                  ),
                ),
                const Divider(height: 32),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_download_outlined),
                    title: const Text('Téléchargements'),
                    subtitle: const Text(
                      'Gérer les vidéos téléchargées et le cache',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.downloads),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un profil'),
        onPressed: () => context.push(AppRoutes.manageNew),
      ),
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    ProfileDto dto,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Supprimer ${dto.name} ?'),
        content: const Text(
          'Cette action est définitive. La progression de visionnage '
          'de ce profil sera perdue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .deleteProfile(profileId: dto.id);
    if (!context.mounted) return;
    switch (result) {
      case DeleteProfileSuccess():
        break;
      case DeleteProfileCannotDeleteMain():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le profil principal ne peut pas être supprimé'),
          ),
        );
      case DeleteProfileUnknownProfile():
      case DeleteProfileInvalidState():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de supprimer ce profil')),
        );
    }
  }
}
