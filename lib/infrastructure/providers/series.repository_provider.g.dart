// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Series repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemorySeriesRepository] — exercises the modal détail
///   UX with the seeded Pingu series.
/// - **non-empty** → [DioSeriesRepository] consuming [dioProvider] — talks
///   to the real backend's `/series/{id}` endpoint at the URL the user
///   configured via the ⚙ dialog on the phone-entry page.

@ProviderFor(seriesRepository)
final seriesRepositoryProvider = SeriesRepositoryProvider._();

/// Series repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemorySeriesRepository] — exercises the modal détail
///   UX with the seeded Pingu series.
/// - **non-empty** → [DioSeriesRepository] consuming [dioProvider] — talks
///   to the real backend's `/series/{id}` endpoint at the URL the user
///   configured via the ⚙ dialog on the phone-entry page.

final class SeriesRepositoryProvider
    extends
        $FunctionalProvider<
          SeriesRepository,
          SeriesRepository,
          SeriesRepository
        >
    with $Provider<SeriesRepository> {
  /// Series repository provider.
  ///
  /// Selects between two implementations based on [apiBaseUrlProvider]:
  ///
  /// - **empty** → [InMemorySeriesRepository] — exercises the modal détail
  ///   UX with the seeded Pingu series.
  /// - **non-empty** → [DioSeriesRepository] consuming [dioProvider] — talks
  ///   to the real backend's `/series/{id}` endpoint at the URL the user
  ///   configured via the ⚙ dialog on the phone-entry page.
  SeriesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seriesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seriesRepositoryHash();

  @$internal
  @override
  $ProviderElement<SeriesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SeriesRepository create(Ref ref) {
    return seriesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SeriesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SeriesRepository>(value),
    );
  }
}

String _$seriesRepositoryHash() => r'e42b4b774aa6baf8fc703d37af8d8cb81e811161';
