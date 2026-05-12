import 'package:kidflix/infrastructure/providers/app_config.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_base_url.provider.g.dart';

/// Holds the API base URL currently in effect. Read synchronously by
/// [dioProvider] and every `*RepositoryProvider` that picks between its
/// in-memory and Dio implementations.
///
/// Resolution order:
/// 1. After [load] has been called (during [bootstrapProvider]), the value
///    is whatever the user persisted via the ⚙ dialog on the phone-entry
///    page (an empty string means "in-memory mode").
/// 2. Before [load], or when nothing has ever been persisted, the value
///    falls back to the compile-time constant
///    `String.fromEnvironment('API_BASE_URL')`. Builds that don't pass
///    `--dart-define=API_BASE_URL=...` therefore start in in-memory mode,
///    preserving the historical behaviour.
///
/// Calling [update] writes to storage AND emits a new state, which causes
/// Riverpod to rebuild [dioProvider] (and the repository providers that
/// watch it) so the next HTTP call uses the new URL.
@Riverpod(keepAlive: true)
class ApiBaseUrl extends _$ApiBaseUrl {
  static const _envFallback = String.fromEnvironment('API_BASE_URL');

  @override
  String build() => _envFallback;

  /// Called once at startup by [bootstrapProvider], before the router or
  /// any repository is built.
  Future<void> load() async {
    final stored = await ref.read(appConfigRepositoryProvider).readApiBaseUrl();
    state = stored ?? _envFallback;
  }

  /// Persists [url] and updates state. An empty string switches the app
  /// back to in-memory mode.
  Future<void> update(String url) async {
    await ref.read(appConfigRepositoryProvider).writeApiBaseUrl(url);
    state = url;
  }
}
