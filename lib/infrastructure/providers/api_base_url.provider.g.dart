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

@ProviderFor(ApiBaseUrl)
final apiBaseUrlProvider = ApiBaseUrlProvider._();

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
final class ApiBaseUrlProvider extends $NotifierProvider<ApiBaseUrl, String> {
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

String _$apiBaseUrlHash() => r'425a09cff616306c3de042623f666abfdc98880e';

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
