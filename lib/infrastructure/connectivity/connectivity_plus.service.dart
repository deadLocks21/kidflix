import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:kidflix/core/domain/services/connectivity.service.dart';

/// [ConnectivityService] backed by the `connectivity_plus` plugin.
///
/// Subscribes once to [Connectivity.onConnectivityChanged] and converts
/// the raw `List<ConnectivityResult>` into a single boolean: online when
/// at least one entry is anything other than [ConnectivityResult.none].
/// The latest value is cached so [isOnline] is a cheap synchronous read
/// and new subscribers immediately receive the current state.
///
/// The initial state is hydrated lazily via [Connectivity.checkConnectivity]
/// on first subscription, then kept fresh by the change stream.
///
/// Robust to [MissingPluginException]: when the native side of the
/// plugin is unavailable (most commonly because the app was hot-reloaded
/// after adding the dependency without a full restart, or on a
/// platform where the plugin is not implemented), we default to
/// "online" so the app keeps working — the user just doesn't get the
/// auto-fallback to the offline catalog.
class ConnectivityPlusService implements ConnectivityService {
  final Connectivity _connectivity;
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _online = true;
  bool _hydrated = false;

  ConnectivityPlusService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    try {
      _subscription = _connectivity.onConnectivityChanged.listen(
        _handle,
        onError: (Object error, StackTrace stack) {
          // The first emission of the stream can surface a
          // MissingPluginException asynchronously — swallow it and stay
          // optimistic (online) rather than crashing the UI.
          if (error is MissingPluginException) {
            _logMissingPlugin(error);
            return;
          }
          developer.log(
            'connectivity_plus stream error — assuming online',
            name: 'kidflix.connectivity',
            level: 900,
            error: error,
            stackTrace: stack,
          );
        },
      );
    } on MissingPluginException catch (e) {
      _logMissingPlugin(e);
    } catch (e, st) {
      developer.log(
        'connectivity_plus subscription failed — assuming online',
        name: 'kidflix.connectivity',
        level: 900,
        error: e,
        stackTrace: st,
      );
    }
    // Fire-and-forget hydration of the initial state. Defers to the
    // stream once it kicks in.
    unawaited(_hydrate());
  }

  void _logMissingPlugin(Object error) {
    developer.log(
      'connectivity_plus native side missing — defaulting to online. '
      'If you just added the dependency, do a full app restart '
      '(stop + flutter run) rather than a hot reload to register the '
      'platform plugin.',
      name: 'kidflix.connectivity',
      level: 900,
      error: error,
    );
  }

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> watch() async* {
    yield _online;
    yield* _controller.stream;
  }

  Future<void> _hydrate() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (!_hydrated) {
        _hydrated = true;
        _handle(results);
      }
    } on MissingPluginException catch (e) {
      _logMissingPlugin(e);
    } catch (_) {
      // Best-effort: stay online by default if the platform throws.
    }
  }

  void _handle(List<ConnectivityResult> results) {
    final next = results.any((r) => r != ConnectivityResult.none);
    if (next == _online && _hydrated) return;
    _hydrated = true;
    _online = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  /// Releases the underlying subscription. Tests / hot-reload paths only.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
