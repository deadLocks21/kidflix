import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/phone_entry/widgets/backend_url_dialog.widget.dart';
import 'package:kidflix/ui/router/app_router.dart';

/// Page Paramètres accessible depuis le menu profil de la home.
///
/// Sections :
/// - **Mon profil** (tous les profils) : édition nom + avatar + code.
/// - **Tranches d'âge à afficher** (profils non-`bebe`) : opt-in sur les
///   catégories strictement inférieures à afficher sur la home.
/// - **URL du backend** (profil principal uniquement) : commute le mode
///   hors-ligne / backend distant.
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
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    final backendSubtitle = apiBaseUrl.isEmpty
        ? 'Mode hors-ligne intégré'
        : apiBaseUrl;

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
                      leading: const Icon(Icons.dns_outlined),
                      title: const Text('URL du backend'),
                      subtitle: Text(backendSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => BackendUrlDialog.show(context),
                    ),
                  ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
