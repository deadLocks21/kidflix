// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatars.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Avatars catalogue repository provider.
///
/// Selects the implementation by the same `String.fromEnvironment('API_BASE_URL')`
/// flag used by `profileManagementRepositoryProvider` and `authRepositoryProvider`
/// — keep them consistent.

@ProviderFor(avatarsRepository)
final avatarsRepositoryProvider = AvatarsRepositoryProvider._();

/// Avatars catalogue repository provider.
///
/// Selects the implementation by the same `String.fromEnvironment('API_BASE_URL')`
/// flag used by `profileManagementRepositoryProvider` and `authRepositoryProvider`
/// — keep them consistent.

final class AvatarsRepositoryProvider
    extends
        $FunctionalProvider<
          AvatarsRepository,
          AvatarsRepository,
          AvatarsRepository
        >
    with $Provider<AvatarsRepository> {
  /// Avatars catalogue repository provider.
  ///
  /// Selects the implementation by the same `String.fromEnvironment('API_BASE_URL')`
  /// flag used by `profileManagementRepositoryProvider` and `authRepositoryProvider`
  /// — keep them consistent.
  AvatarsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'avatarsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$avatarsRepositoryHash();

  @$internal
  @override
  $ProviderElement<AvatarsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AvatarsRepository create(Ref ref) {
    return avatarsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AvatarsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AvatarsRepository>(value),
    );
  }
}

String _$avatarsRepositoryHash() => r'c0079f60c1624b150f6809e3aa297c3dd8a97b46';
