// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Download repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryDownloadRepository] — used by tests and when no
///   backend has been configured. Streams Big Buck Bunny from archive.org
///   through a private `Dio` (no auth interceptor, so credentials never
///   leak to the third-party CDN).
/// - **non-empty** → [DioDownloadRepository] consuming [dioProvider] —
///   hits `GET /movies/{movie_id}/download` on the Kidflix backend with
///   `Authorization: Bearer <jwt>` and `X-Device-Id` headers injected
///   transparently by the `AuthInterceptor`. The URL is configured by the
///   user via the ⚙ dialog on the phone-entry page.

@ProviderFor(downloadRepository)
final downloadRepositoryProvider = DownloadRepositoryProvider._();

/// Download repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryDownloadRepository] — used by tests and when no
///   backend has been configured. Streams Big Buck Bunny from archive.org
///   through a private `Dio` (no auth interceptor, so credentials never
///   leak to the third-party CDN).
/// - **non-empty** → [DioDownloadRepository] consuming [dioProvider] —
///   hits `GET /movies/{movie_id}/download` on the Kidflix backend with
///   `Authorization: Bearer <jwt>` and `X-Device-Id` headers injected
///   transparently by the `AuthInterceptor`. The URL is configured by the
///   user via the ⚙ dialog on the phone-entry page.

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
  /// Selects between two implementations based on [apiBaseUrlProvider]:
  ///
  /// - **empty** → [InMemoryDownloadRepository] — used by tests and when no
  ///   backend has been configured. Streams Big Buck Bunny from archive.org
  ///   through a private `Dio` (no auth interceptor, so credentials never
  ///   leak to the third-party CDN).
  /// - **non-empty** → [DioDownloadRepository] consuming [dioProvider] —
  ///   hits `GET /movies/{movie_id}/download` on the Kidflix backend with
  ///   `Authorization: Bearer <jwt>` and `X-Device-Id` headers injected
  ///   transparently by the `AuthInterceptor`. The URL is configured by the
  ///   user via the ⚙ dialog on the phone-entry page.
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
    r'31b9e7d4a529a2cc3677a8abb35bad0cf136243d';
