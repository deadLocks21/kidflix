import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
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
    );
  }
}
