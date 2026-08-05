import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/providers/app_version.provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/router/app_router.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Page Paramètres accessible depuis le menu profil de la home.
///
/// Sections :
/// - **Mon profil** (tous les profils) : édition nom + avatar + code.
/// - **Tranches d'âge à afficher** (profils non-`bebe`) : opt-in sur les
///   catégories strictement inférieures à afficher sur la home.
/// - **Téléchargements & stockage** (profil principal uniquement) :
///   gestion des vidéos téléchargées et du cache.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final isMain = session is ProfileSelected && session.profile.isMain;
    final hasLowerAges =
        session is ProfileSelected &&
        session.profile.ageCategory != AgeCategory.bebe;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Mon profil'),
                    subtitle: const Text(
                      'Modifier le nom, l\'avatar et le code',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.settingsProfile),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.visibility_outlined),
                    title: const Text('Films déjà vus'),
                    subtitle: const Text(
                      'Marquer en masse les films déjà regardés',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.settingsSeen),
                  ),
                ),
                if (hasLowerAges) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.filter_alt_outlined),
                      title: const Text('Tranches d\'âge à afficher'),
                      subtitle: const Text(
                        'Choisir les âges inférieurs visibles sur la home',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.settingsAges),
                    ),
                  ),
                ],
                if (isMain) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_download_outlined),
                      title: const Text('Téléchargements & stockage'),
                      subtitle: const Text(
                        'Gérer les vidéos téléchargées et le cache',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.settingsDownloads),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const _AppVersionLabel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Numéro de version discret en pied de page. Rendu vide tant que la lecture
/// des métadonnées du bundle est en vol, et en cas d'échec : la version est
/// une information de confort, jamais un message d'erreur à afficher.
class _AppVersionLabel extends ConsumerWidget {
  const _AppVersionLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value;
    if (version == null) return const SizedBox.shrink();

    return Center(
      child: Text(
        'v$version',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: KidflixPalette.white),
      ),
    );
  }
}
