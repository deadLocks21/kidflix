import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/infrastructure/providers/logger.service_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/router/app_router.dart';
import 'package:kidflix/ui/theme/app_theme_data.dart';
import 'package:kidflix/updating_splash.dart';
import 'package:media_kit/media_kit.dart';

void main(List<String> args) {
  // Mode « fenêtre de mise à jour » : l'updater lance `kidflix --updating
  // --status <chemin>` pour afficher une petite fenêtre de progression native
  // pendant qu'il télécharge/installe la nouvelle version. On NE démarre PAS
  // l'app complète dans ce cas.
  if (args.contains('--updating')) {
    runUpdatingSplash(args);
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Build the Riverpod container manually so we can read the logger
  // before `runApp` and wire the framework-wide error handlers below.
  final container = ProviderContainer();
  final logger = container.read(loggerProvider);

  _installErrorHandlers(logger);
  _lifecycleFlush = _installLifecycleFlush(logger);
  logger.info('app.started');

  runApp(
    UncontrolledProviderScope(container: container, child: const KidflixApp()),
  );
}

/// Held for the process lifetime so the listener is never collected —
/// it deregisters itself from [WidgetsBinding] on finalization.
// ignore: unused_element
AppLifecycleListener? _lifecycleFlush;

/// Ships the logger's batch buffer every time the app leaves the
/// foreground, and records the transition itself.
///
/// [SignozLoggerService] otherwise only flushes on its 10 s timer and
/// never retries a failed batch, so the last few seconds before the
/// process dies are lost. That window is precisely the one worth reading:
/// the reports that matter all end with the user force-quitting an app
/// that had stopped responding, which means the evidence of *why* it
/// stopped is exactly what never gets shipped.
///
/// `detached` is best-effort — the platform may kill the process before
/// the POST completes. `hidden` / `paused` are the ones that do the real
/// work, because they fire when the app is merely backgrounded, well
/// before the user gets around to swiping it away.
///
/// `app.lifecycle` is also the marker that says an apparent gap in the
/// timeline was the app being away rather than the app being stuck.
AppLifecycleListener _installLifecycleFlush(LoggerApplicationService logger) {
  void mark(String state, {required bool flush}) {
    unawaited(logger.info('app.lifecycle', attrs: {'app.state': state}));
    if (flush) unawaited(logger.flush());
  }

  return AppLifecycleListener(
    onHide: () => mark('hidden', flush: true),
    onPause: () => mark('paused', flush: true),
    onDetach: () => mark('detached', flush: true),
    // No forced flush on the way back in: the periodic timer picks these
    // up, and the process is not about to disappear.
    onShow: () => mark('shown', flush: false),
    onResume: () => mark('resumed', flush: false),
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
