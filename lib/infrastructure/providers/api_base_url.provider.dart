import 'package:kidflix/infrastructure/providers/app_config.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_base_url.provider.g.dart';

/// The public demo-mode URL. Treated as an alias for in-memory mode (see
/// [isInMemoryBaseUrl]) so a fresh install can show a recognisable host
/// in the ⚙ dialog while still running entirely offline.
const kDemoApiBaseUrl = 'https://demo.kidflix.io';

/// Returns `true` when [url] should be treated as "no real backend" —
/// either the user explicitly cleared the field (empty) or they're on
/// the demo alias. Every `*RepositoryProvider` uses this to pick its
/// `InMemory*` implementation; [resolveAvatarFullUrl] uses it to skip
/// the network fetch and fall back to the letter placeholder.
bool isInMemoryBaseUrl(String url) => url.isEmpty || url == kDemoApiBaseUrl;

/// Holds the API base URL currently in effect. Read synchronously by
/// [dioProvider] and every `*RepositoryProvider` that picks between its
/// in-memory and Dio implementations.
///
/// Resolution order (highest precedence first):
/// 1. The value the user persisted via the ⚙ dialog on the phone-entry
///    page (an empty string means "in-memory mode" and is preserved
///    verbatim — that's how the user opts out of any backend).
/// 2. The compile-time constant `String.fromEnvironment('API_BASE_URL')`,
///    so `--dart-define=API_BASE_URL=...` still pins a URL for CI / dev
///    builds when nothing has been persisted yet.
/// 3. [kDemoApiBaseUrl] — the public demo URL shown on a fresh install.
///    It maps to in-memory mode via [isInMemoryBaseUrl].
///
/// Before [load] has been called (e.g. in unit tests that don't run
/// [bootstrapProvider]) the state is whatever the env var resolves to,
/// which keeps the historical test behaviour (empty → in-memory) intact.
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
    if (stored != null) {
      state = stored;
      return;
    }
    state = _envFallback.isEmpty ? kDemoApiBaseUrl : _envFallback;
  }

  /// Persists [url] and updates state. An empty string switches the app
  /// back to in-memory mode.
  Future<void> update(String url) async {
    await ref.read(appConfigRepositoryProvider).writeApiBaseUrl(url);
    state = url;
  }
}
