// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Series repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemorySeriesRepository] — exercises the
///   modal détail UX with the seeded Pingu series.
/// - **non-empty** → [DioSeriesRepository] consuming [dioProvider] —
///   talks to the real backend's `/series/{id}` endpoint.
///
/// Switching modes requires a full rebuild.

@ProviderFor(seriesRepository)
final seriesRepositoryProvider = SeriesRepositoryProvider._();

/// Series repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemorySeriesRepository] — exercises the
///   modal détail UX with the seeded Pingu series.
/// - **non-empty** → [DioSeriesRepository] consuming [dioProvider] —
///   talks to the real backend's `/series/{id}` endpoint.
///
/// Switching modes requires a full rebuild.

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
  /// Selects between two implementations based on the compile-time constant
  /// `String.fromEnvironment('API_BASE_URL')`:
  ///
  /// - **empty (default)** → [InMemorySeriesRepository] — exercises the
  ///   modal détail UX with the seeded Pingu series.
  /// - **non-empty** → [DioSeriesRepository] consuming [dioProvider] —
  ///   talks to the real backend's `/series/{id}` endpoint.
  ///
  /// Switching modes requires a full rebuild.
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

String _$seriesRepositoryHash() => r'd4e2f2ee745c442a07fb80e97c863b98c18288e8';
