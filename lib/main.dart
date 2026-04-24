import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/router/app_router.dart';
import 'package:kidflix/ui/theme/app_theme_data.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: KidflixApp()));
}

class KidflixApp extends ConsumerWidget {
  const KidflixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);
    final theme = AppThemeData.buildDarkTheme();
    return bootstrap.when(
      data: (_) => MaterialApp.router(
        title: 'Kidflix',
        theme: theme,
        routerConfig: ref.watch(appRouterProvider),
      ),
      loading: () => MaterialApp(
        title: 'Kidflix',
        theme: theme,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, _) => MaterialApp(
        title: 'Kidflix',
        theme: theme,
        home: Scaffold(
          body: Center(child: Text('Erreur au démarrage : $error')),
        ),
      ),
    );
  }
}
