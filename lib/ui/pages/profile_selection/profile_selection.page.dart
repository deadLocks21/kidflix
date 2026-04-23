import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/enter_management_mode.usecase.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/profile_selection/widgets/profile_avatar.widget.dart';

class ProfileSelectionPage extends ConsumerWidget {
  const ProfileSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    final session = switch (state) {
      Authenticated(:final session) => session,
      ProfileSelected(:final session) => session,
      PinRequired(:final session) => session,
      ManagementPinRequired(:final session) => session,
      ManagingProfiles(:final session) => session,
      _ => null,
    };
    final profiles =
        session?.profiles.map(ProfileDto.fromDomain).toList(growable: false) ??
        const <ProfileDto>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qui regarde ?'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Wrap(
                    spacing: 32,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    children: [
                      for (final dto in profiles)
                        SizedBox(
                          width: 140,
                          child: ProfileAvatar(
                            profile: dto,
                            onTap: () => ref
                                .read(sessionControllerProvider.notifier)
                                .selectProfile(dto.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.manage_accounts),
                      label: const Text('Gérer les profils'),
                      onPressed: () => _enterManagement(context, ref),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _enterManagement(BuildContext context, WidgetRef ref) {
    final result =
        ref.read(sessionControllerProvider.notifier).enterManagementMode();
    switch (result) {
      case EnterManagementModeSuccess():
        // Router redirects automatically on state change.
        break;
      case EnterManagementModeNoMainProfile():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun profil principal détecté sur ce compte',
            ),
          ),
        );
      case EnterManagementModeInvalidState():
        break;
    }
  }
}
