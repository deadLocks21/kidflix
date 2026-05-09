// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_preferences.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Audio + subtitle language preferences are stored locally on the
/// device — no backend involvement — so the provider always returns the
/// `SharedPreferences`-backed implementation. Tests override this
/// provider with `InMemoryTrackPreferencesRepository`.

@ProviderFor(trackPreferencesRepository)
final trackPreferencesRepositoryProvider =
    TrackPreferencesRepositoryProvider._();

/// Audio + subtitle language preferences are stored locally on the
/// device — no backend involvement — so the provider always returns the
/// `SharedPreferences`-backed implementation. Tests override this
/// provider with `InMemoryTrackPreferencesRepository`.

final class TrackPreferencesRepositoryProvider
    extends
        $FunctionalProvider<
          TrackPreferencesRepository,
          TrackPreferencesRepository,
          TrackPreferencesRepository
        >
    with $Provider<TrackPreferencesRepository> {
  /// Audio + subtitle language preferences are stored locally on the
  /// device — no backend involvement — so the provider always returns the
  /// `SharedPreferences`-backed implementation. Tests override this
  /// provider with `InMemoryTrackPreferencesRepository`.
  TrackPreferencesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackPreferencesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackPreferencesRepositoryHash();

  @$internal
  @override
  $ProviderElement<TrackPreferencesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrackPreferencesRepository create(Ref ref) {
    return trackPreferencesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrackPreferencesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrackPreferencesRepository>(value),
    );
  }
}

String _$trackPreferencesRepositoryHash() =>
    r'683040e1292343b25bc7ee8ea457f93585dac275';
