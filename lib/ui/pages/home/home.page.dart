import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';

/// Stub homepage affichée après la sélection d'un profil. Affiche le nom
/// du profil actif et expose un bouton de déconnexion. Sera remplacée par
/// le catalogue en Phase 3.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    final name = state is ProfileSelected ? state.profile.name : '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kidflix'),
        actions: [
          IconButton(
            tooltip: 'Changer de profil',
            icon: const Icon(Icons.switch_account),
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).deselectProfile(),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Bienvenue $name',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
