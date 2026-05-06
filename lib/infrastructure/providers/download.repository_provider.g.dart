// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Download repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryDownloadRepository] — used by tests, by
///   `flutter run` without flag, and by anyone running offline. Streams
///   Big Buck Bunny from archive.org through a private `Dio` (no auth
///   interceptor, so credentials never leak to the third-party CDN).
/// - **non-empty** → [DioDownloadRepository] consuming [dioProvider] —
///   hits `GET /movies/{movie_id}/download` on the Kidflix backend with
///   `Authorization: Bearer <jwt>` and `X-Device-Id` headers injected
///   transparently by the `AuthInterceptor`. Used by
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.

@ProviderFor(downloadRepository)
final downloadRepositoryProvider = DownloadRepositoryProvider._();

/// Download repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryDownloadRepository] — used by tests, by
///   `flutter run` without flag, and by anyone running offline. Streams
///   Big Buck Bunny from archive.org through a private `Dio` (no auth
///   interceptor, so credentials never leak to the third-party CDN).
/// - **non-empty** → [DioDownloadRepository] consuming [dioProvider] —
///   hits `GET /movies/{movie_id}/download` on the Kidflix backend with
///   `Authorization: Bearer <jwt>` and `X-Device-Id` headers injected
///   transparently by the `AuthInterceptor`. Used by
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.

final class DownloadRepositoryProvider
    extends
        $FunctionalProvider<
          DownloadRepository,
          DownloadRepository,
          DownloadRepository
        >
    with $Provider<DownloadRepository> {
  /// Download repository provider.
  ///
  /// Selects between two implementations based on the compile-time constant
  /// `String.fromEnvironment('API_BASE_URL')`:
  ///
  /// - **empty (default)** → [InMemoryDownloadRepository] — used by tests, by
  ///   `flutter run` without flag, and by anyone running offline. Streams
  ///   Big Buck Bunny from archive.org through a private `Dio` (no auth
  ///   interceptor, so credentials never leak to the third-party CDN).
  /// - **non-empty** → [DioDownloadRepository] consuming [dioProvider] —
  ///   hits `GET /movies/{movie_id}/download` on the Kidflix backend with
  ///   `Authorization: Bearer <jwt>` and `X-Device-Id` headers injected
  ///   transparently by the `AuthInterceptor`. Used by
  ///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
  ///
  /// Switching modes requires a full rebuild — `String.fromEnvironment` is
  /// evaluated at compile time, not at runtime.
  DownloadRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadRepositoryHash();

  @$internal
  @override
  $ProviderElement<DownloadRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadRepository create(Ref ref) {
    return downloadRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadRepository>(value),
    );
  }
}

String _$downloadRepositoryHash() =>
    r'6a4632898435ddbf850e31e51a1d8112566efedd';
