// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_management.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Profile-management repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryProfileManagementRepository] — used by
///   tests, by `flutter run` without flag, and by anyone running offline.
/// - **non-empty** → [DioProfileManagementRepository] consuming [dioProvider]
///   — used to talk to the real backend, e.g.
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild. The selection MUST stay
/// consistent with `authRepositoryProvider` — they read the same flag.

@ProviderFor(profileManagementRepository)
final profileManagementRepositoryProvider =
    ProfileManagementRepositoryProvider._();

/// Profile-management repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryProfileManagementRepository] — used by
///   tests, by `flutter run` without flag, and by anyone running offline.
/// - **non-empty** → [DioProfileManagementRepository] consuming [dioProvider]
///   — used to talk to the real backend, e.g.
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild. The selection MUST stay
/// consistent with `authRepositoryProvider` — they read the same flag.

final class ProfileManagementRepositoryProvider
    extends
        $FunctionalProvider<
          ProfileManagementRepository,
          ProfileManagementRepository,
          ProfileManagementRepository
        >
    with $Provider<ProfileManagementRepository> {
  /// Profile-management repository provider.
  ///
  /// Selects between two implementations based on the compile-time constant
  /// `String.fromEnvironment('API_BASE_URL')`:
  ///
  /// - **empty (default)** → [InMemoryProfileManagementRepository] — used by
  ///   tests, by `flutter run` without flag, and by anyone running offline.
  /// - **non-empty** → [DioProfileManagementRepository] consuming [dioProvider]
  ///   — used to talk to the real backend, e.g.
  ///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
  ///
  /// Switching modes requires a full rebuild. The selection MUST stay
  /// consistent with `authRepositoryProvider` — they read the same flag.
  ProfileManagementRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileManagementRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileManagementRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileManagementRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileManagementRepository create(Ref ref) {
    return profileManagementRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileManagementRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileManagementRepository>(value),
    );
  }
}

String _$profileManagementRepositoryHash() =>
    r'eb7447d71f33ad9e3671a736986ccb61f9c6afe0';
