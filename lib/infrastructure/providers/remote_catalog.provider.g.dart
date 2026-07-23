// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_catalog.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The host's active profile id, or null when not driving a ready host.
///
/// A derived primitive on purpose: the connection stream re-emits on
/// every position tick, but this value only changes when the host
/// actually switches profile — so Riverpod's equality check keeps
/// downstream fetches from rerunning once a second.

@ProviderFor(hostActiveProfileId)
final hostActiveProfileIdProvider = HostActiveProfileIdProvider._();

/// The host's active profile id, or null when not driving a ready host.
///
/// A derived primitive on purpose: the connection stream re-emits on
/// every position tick, but this value only changes when the host
/// actually switches profile — so Riverpod's equality check keeps
/// downstream fetches from rerunning once a second.

final class HostActiveProfileIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// The host's active profile id, or null when not driving a ready host.
  ///
  /// A derived primitive on purpose: the connection stream re-emits on
  /// every position tick, but this value only changes when the host
  /// actually switches profile — so Riverpod's equality check keeps
  /// downstream fetches from rerunning once a second.
  HostActiveProfileIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hostActiveProfileIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hostActiveProfileIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return hostActiveProfileId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$hostActiveProfileIdHash() =>
    r'a2e919cae2ae82eac43a2acfd6283adac0359afd';

/// True while this device should show a host's catalogue instead of its
/// own: connected, and the host has an active profile to show one for.
///
/// When the host has no profile yet the remote shows its profile picker,
/// not a catalogue, so this stays false until the host is `ready`.

@ProviderFor(viewingHostCatalogue)
final viewingHostCatalogueProvider = ViewingHostCatalogueProvider._();

/// True while this device should show a host's catalogue instead of its
/// own: connected, and the host has an active profile to show one for.
///
/// When the host has no profile yet the remote shows its profile picker,
/// not a catalogue, so this stays false until the host is `ready`.

final class ViewingHostCatalogueProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// True while this device should show a host's catalogue instead of its
  /// own: connected, and the host has an active profile to show one for.
  ///
  /// When the host has no profile yet the remote shows its profile picker,
  /// not a catalogue, so this stays false until the host is `ready`.
  ViewingHostCatalogueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewingHostCatalogueProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewingHostCatalogueHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return viewingHostCatalogue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$viewingHostCatalogueHash() =>
    r'fefa8ddf6506f6713e41dcc8da41b5c215c5e9c8';

/// The home rows of the host this device is driving, fetched from the
/// host over the socket.
///
/// This is the whole point of driving from a remote: you see the *host's*
/// catalogue — its active profile's rows, its age filter, its "Ma liste"
/// — not your own. The local account cannot fetch it (the backend 403s a
/// profile it does not own), so the host serves it.
///
/// Re-fetches whenever the host's active profile changes: the session
/// snapshot rides on every playback push, so watching the active profile
/// id reruns this the moment someone switches profile on the host.

@ProviderFor(remoteHomeRows)
final remoteHomeRowsProvider = RemoteHomeRowsProvider._();

/// The home rows of the host this device is driving, fetched from the
/// host over the socket.
///
/// This is the whole point of driving from a remote: you see the *host's*
/// catalogue — its active profile's rows, its age filter, its "Ma liste"
/// — not your own. The local account cannot fetch it (the backend 403s a
/// profile it does not own), so the host serves it.
///
/// Re-fetches whenever the host's active profile changes: the session
/// snapshot rides on every playback push, so watching the active profile
/// id reruns this the moment someone switches profile on the host.

final class RemoteHomeRowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CatalogRowDto>>,
          List<CatalogRowDto>,
          FutureOr<List<CatalogRowDto>>
        >
    with
        $FutureModifier<List<CatalogRowDto>>,
        $FutureProvider<List<CatalogRowDto>> {
  /// The home rows of the host this device is driving, fetched from the
  /// host over the socket.
  ///
  /// This is the whole point of driving from a remote: you see the *host's*
  /// catalogue — its active profile's rows, its age filter, its "Ma liste"
  /// — not your own. The local account cannot fetch it (the backend 403s a
  /// profile it does not own), so the host serves it.
  ///
  /// Re-fetches whenever the host's active profile changes: the session
  /// snapshot rides on every playback push, so watching the active profile
  /// id reruns this the moment someone switches profile on the host.
  RemoteHomeRowsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteHomeRowsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteHomeRowsHash();

  @$internal
  @override
  $FutureProviderElement<List<CatalogRowDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CatalogRowDto>> create(Ref ref) {
    return remoteHomeRows(ref);
  }
}

String _$remoteHomeRowsHash() => r'ca64147dff7b1554d888490c2ea383eee681561c';

/// Full detail for one movie in the host's catalogue, fetched from the
/// host. Used by the remote's detail sheet, since the same 403 blocks the
/// local account from reading it directly.

@ProviderFor(remoteMovieDetail)
final remoteMovieDetailProvider = RemoteMovieDetailFamily._();

/// Full detail for one movie in the host's catalogue, fetched from the
/// host. Used by the remote's detail sheet, since the same 403 blocks the
/// local account from reading it directly.

final class RemoteMovieDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<MovieDetailDto>,
          MovieDetailDto,
          FutureOr<MovieDetailDto>
        >
    with $FutureModifier<MovieDetailDto>, $FutureProvider<MovieDetailDto> {
  /// Full detail for one movie in the host's catalogue, fetched from the
  /// host. Used by the remote's detail sheet, since the same 403 blocks the
  /// local account from reading it directly.
  RemoteMovieDetailProvider._({
    required RemoteMovieDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'remoteMovieDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$remoteMovieDetailHash();

  @override
  String toString() {
    return r'remoteMovieDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MovieDetailDto> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MovieDetailDto> create(Ref ref) {
    final argument = this.argument as String;
    return remoteMovieDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RemoteMovieDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$remoteMovieDetailHash() => r'd7baefaca89037d7c6a90b1992cb4d049f4ff9aa';

/// Full detail for one movie in the host's catalogue, fetched from the
/// host. Used by the remote's detail sheet, since the same 403 blocks the
/// local account from reading it directly.

final class RemoteMovieDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MovieDetailDto>, String> {
  RemoteMovieDetailFamily._()
    : super(
        retry: null,
        name: r'remoteMovieDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Full detail for one movie in the host's catalogue, fetched from the
  /// host. Used by the remote's detail sheet, since the same 403 blocks the
  /// local account from reading it directly.

  RemoteMovieDetailProvider call(String movieId) =>
      RemoteMovieDetailProvider._(argument: movieId, from: this);

  @override
  String toString() => r'remoteMovieDetailProvider';
}
