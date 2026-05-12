// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatars.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Avatars catalogue repository provider.
///
/// Selects the implementation by reading [apiBaseUrlProvider] — same source
/// used by `profileManagementRepositoryProvider` and `authRepositoryProvider`,
/// so all three stay consistent when the user switches backend.

@ProviderFor(avatarsRepository)
final avatarsRepositoryProvider = AvatarsRepositoryProvider._();

/// Avatars catalogue repository provider.
///
/// Selects the implementation by reading [apiBaseUrlProvider] — same source
/// used by `profileManagementRepositoryProvider` and `authRepositoryProvider`,
/// so all three stay consistent when the user switches backend.

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
  /// Selects the implementation by reading [apiBaseUrlProvider] — same source
  /// used by `profileManagementRepositoryProvider` and `authRepositoryProvider`,
  /// so all three stay consistent when the user switches backend.
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

String _$avatarsRepositoryHash() => r'1becbe85ebba8e77574287e50c17992d589ff539';
