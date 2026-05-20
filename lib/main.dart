import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/infrastructure/providers/logger.service_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/router/app_router.dart';
import 'package:kidflix/ui/theme/app_theme_data.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Build the Riverpod container manually so we can read the logger
  // before `runApp` and wire the framework-wide error handlers below.
  final container = ProviderContainer();
  final logger = container.read(loggerProvider);

  _installErrorHandlers(logger);
  logger.info('app.started');

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const KidflixApp(),
    ),
  );
}

/// Routes uncaught Flutter/Dart errors to the logger.
///
/// Two hooks cover the vast majority of failures on the Dart side:
///
/// - [FlutterError.onError] — synchronous errors raised by the framework
///   (widget build, layout, render, assertions).
/// - [PlatformDispatcher.onError] — asynchronous Dart errors that
///   escape every `Future`/`Stream`/zone above them (the catch-all of
///   last resort introduced in Flutter 3.3).
///
/// Native crashes (Swift/Obj-C on iOS, JVM on Android, FFI libs like
/// media_kit) bypass both hooks — they kill the Dart isolate before
/// either runs. Add Crashlytics or Sentry if those start to matter.
void _installErrorHandlers(LoggerApplicationService logger) {
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    logger.error(
      'flutter.error',
      error: details.exception,
      stack: details.stack,
      attrs: {
        if (details.library != null) 'flutter.library': details.library!,
        if (details.context != null)
          'flutter.context': details.context!.toString(),
      },
    );
    // Keep the default behaviour (red error screen in debug, console
    // dump elsewhere) so we don't silently hide errors during dev.
    defaultOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error('dart.uncaught', error: error, stack: stack);
    // Return `true` to mark the error as handled. The app continues to
    // run rather than letting the error propagate to the platform.
    return true;
  };

  if (kDebugMode) {
    // Belt-and-braces: surface logger init in the console so the first
    // log line of every dev run is visible.
    debugPrint('logger: error handlers installed');
  }
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
