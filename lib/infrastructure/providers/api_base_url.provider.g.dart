// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_base_url.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(ApiBaseUrl)
final apiBaseUrlProvider = ApiBaseUrlProvider._();

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
final class ApiBaseUrlProvider extends $NotifierProvider<ApiBaseUrl, String> {
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
  ApiBaseUrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiBaseUrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiBaseUrlHash();

  @$internal
  @override
  ApiBaseUrl create() => ApiBaseUrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$apiBaseUrlHash() => r'200009f2602e70fd8b07b822c69712b25ef0d9c8';

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

abstract class _$ApiBaseUrl extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
