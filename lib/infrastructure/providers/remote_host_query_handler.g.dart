// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_host_query_handler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Answers the data requests a remote makes of this host.
///
/// The remote asks because it *cannot* read this content itself: the
/// backend scopes every content route to the caller's own account, so a
/// remote signed into a different account than this host gets 403 for
/// this host's catalogue. This host can read it — under its own active
/// profile — and hands the result back.
///
/// It reuses the host's *own* [homeCatalogRowsProvider] and detail path,
/// so a remote sees byte-for-byte what the host's own home shows for the
/// active profile, filters and all.

@ProviderFor(remoteHostQueryHandler)
final remoteHostQueryHandlerProvider = RemoteHostQueryHandlerProvider._();

/// Answers the data requests a remote makes of this host.
///
/// The remote asks because it *cannot* read this content itself: the
/// backend scopes every content route to the caller's own account, so a
/// remote signed into a different account than this host gets 403 for
/// this host's catalogue. This host can read it — under its own active
/// profile — and hands the result back.
///
/// It reuses the host's *own* [homeCatalogRowsProvider] and detail path,
/// so a remote sees byte-for-byte what the host's own home shows for the
/// active profile, filters and all.

final class RemoteHostQueryHandlerProvider
    extends
        $FunctionalProvider<
          RemoteHostQueryHandler,
          RemoteHostQueryHandler,
          RemoteHostQueryHandler
        >
    with $Provider<RemoteHostQueryHandler> {
  /// Answers the data requests a remote makes of this host.
  ///
  /// The remote asks because it *cannot* read this content itself: the
  /// backend scopes every content route to the caller's own account, so a
  /// remote signed into a different account than this host gets 403 for
  /// this host's catalogue. This host can read it — under its own active
  /// profile — and hands the result back.
  ///
  /// It reuses the host's *own* [homeCatalogRowsProvider] and detail path,
  /// so a remote sees byte-for-byte what the host's own home shows for the
  /// active profile, filters and all.
  RemoteHostQueryHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteHostQueryHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteHostQueryHandlerHash();

  @$internal
  @override
  $ProviderElement<RemoteHostQueryHandler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemoteHostQueryHandler create(Ref ref) {
    return remoteHostQueryHandler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteHostQueryHandler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteHostQueryHandler>(value),
    );
  }
}

String _$remoteHostQueryHandlerHash() =>
    r'73a9a79cdd0dc898fadc02de438903441c3afcd8';
