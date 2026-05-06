// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_cleanup_preferences.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(cacheCleanupPreferences)
final cacheCleanupPreferencesProvider = CacheCleanupPreferencesProvider._();

final class CacheCleanupPreferencesProvider
    extends
        $FunctionalProvider<
          CacheCleanupPreferences,
          CacheCleanupPreferences,
          CacheCleanupPreferences
        >
    with $Provider<CacheCleanupPreferences> {
  CacheCleanupPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheCleanupPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheCleanupPreferencesHash();

  @$internal
  @override
  $ProviderElement<CacheCleanupPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CacheCleanupPreferences create(Ref ref) {
    return cacheCleanupPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CacheCleanupPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CacheCleanupPreferences>(value),
    );
  }
}

String _$cacheCleanupPreferencesHash() =>
    r'a9b04f22c604a07650b0d0923d6acd162d633791';
