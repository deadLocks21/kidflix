// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatars.usecases_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(listAvatarsUseCase)
final listAvatarsUseCaseProvider = ListAvatarsUseCaseProvider._();

final class ListAvatarsUseCaseProvider
    extends
        $FunctionalProvider<
          ListAvatarsUseCase,
          ListAvatarsUseCase,
          ListAvatarsUseCase
        >
    with $Provider<ListAvatarsUseCase> {
  ListAvatarsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listAvatarsUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listAvatarsUseCaseHash();

  @$internal
  @override
  $ProviderElement<ListAvatarsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ListAvatarsUseCase create(Ref ref) {
    return listAvatarsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ListAvatarsUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ListAvatarsUseCase>(value),
    );
  }
}

String _$listAvatarsUseCaseHash() =>
    r'52f25acf8bba706e40c3f06ed0232c9186784242';

/// Cached server-side avatar catalogue, fetched once per app session.
///
/// `keepAlive: true` matches the `Cache-Control: max-age=3600` the server
/// publishes on `GET /avatars` — and goes further: a single fetch per app
/// run is enough since the whitelist only evolves at server release
/// boundaries. To force a refetch after a server release, restart the app.

@ProviderFor(avatarsList)
final avatarsListProvider = AvatarsListProvider._();

/// Cached server-side avatar catalogue, fetched once per app session.
///
/// `keepAlive: true` matches the `Cache-Control: max-age=3600` the server
/// publishes on `GET /avatars` — and goes further: a single fetch per app
/// run is enough since the whitelist only evolves at server release
/// boundaries. To force a refetch after a server release, restart the app.

final class AvatarsListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AvatarOptionDto>>,
          List<AvatarOptionDto>,
          FutureOr<List<AvatarOptionDto>>
        >
    with
        $FutureModifier<List<AvatarOptionDto>>,
        $FutureProvider<List<AvatarOptionDto>> {
  /// Cached server-side avatar catalogue, fetched once per app session.
  ///
  /// `keepAlive: true` matches the `Cache-Control: max-age=3600` the server
  /// publishes on `GET /avatars` — and goes further: a single fetch per app
  /// run is enough since the whitelist only evolves at server release
  /// boundaries. To force a refetch after a server release, restart the app.
  AvatarsListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'avatarsListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$avatarsListHash();

  @$internal
  @override
  $FutureProviderElement<List<AvatarOptionDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AvatarOptionDto>> create(Ref ref) {
    return avatarsList(ref);
  }
}

String _$avatarsListHash() => r'1766a1aff2e9b01a267f9064ca3b209c152af81a';
