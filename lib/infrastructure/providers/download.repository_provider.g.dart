// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Download repository provider.
///
/// Currently always returns [InMemoryDownloadRepository]. Will gain an
/// HTTP variant when the backend is available.

@ProviderFor(downloadRepository)
final downloadRepositoryProvider = DownloadRepositoryProvider._();

/// Download repository provider.
///
/// Currently always returns [InMemoryDownloadRepository]. Will gain an
/// HTTP variant when the backend is available.

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
  /// Currently always returns [InMemoryDownloadRepository]. Will gain an
  /// HTTP variant when the backend is available.
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
    r'20bda76472ff8ccda4bcd7f382d0c828b6fda57c';
