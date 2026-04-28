// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_profile_id.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Derived view over [SessionState]: the id of the profile considered
/// **active** for outgoing HTTP requests, or `null` when no profile is
/// active yet.
///
/// Mapping over the seven [SessionState] variants:
///
/// | Variant                       | Returned                                 |
/// |-------------------------------|------------------------------------------|
/// | `Anonymous`                   | `null`                                   |
/// | `OtpRequested(...)`           | `null`                                   |
/// | `Authenticated(session)`      | `null` (logged in, no profile picked yet) |
/// | `PinRequired(profile, _)`     | `profile.id`                             |
/// | `ProfileSelected(profile, _)` | `profile.id`                             |
/// | `ManagementPinRequired(s)`    | `s.profiles.firstWhere(isMain).id`       |
/// | `ManagingProfiles(s)`         | `s.profiles.firstWhere(isMain).id`       |
///
/// In `ManagementPinRequired` and `ManagingProfiles`, the active profile
/// is **the main profile** (derived from the session's profile list, not
/// stored separately on the state). The spec
/// `profile-management` § "Enter profile management mode gated by main
/// profile PIN" guarantees these states are only reachable when a main
/// profile exists in the session, so `firstWhere(isMain)` does not need a
/// fallback — a missing main profile would be an orchestration bug, and
/// surfaces as `StateError` from `firstWhere`.
///
/// Primary consumer: the `AuthInterceptor` registered on `dioProvider`,
/// which uses this id to inject the `X-Profile-Id` header on protected
/// requests (everything except `/auth/*` and the bootstrap
/// `GET /profiles`).
///
/// The exhaustive `switch` over the sealed [SessionState] guarantees a
/// compile-time error if a new variant is added without updating this
/// mapping.

@ProviderFor(currentProfileId)
final currentProfileIdProvider = CurrentProfileIdProvider._();

/// Derived view over [SessionState]: the id of the profile considered
/// **active** for outgoing HTTP requests, or `null` when no profile is
/// active yet.
///
/// Mapping over the seven [SessionState] variants:
///
/// | Variant                       | Returned                                 |
/// |-------------------------------|------------------------------------------|
/// | `Anonymous`                   | `null`                                   |
/// | `OtpRequested(...)`           | `null`                                   |
/// | `Authenticated(session)`      | `null` (logged in, no profile picked yet) |
/// | `PinRequired(profile, _)`     | `profile.id`                             |
/// | `ProfileSelected(profile, _)` | `profile.id`                             |
/// | `ManagementPinRequired(s)`    | `s.profiles.firstWhere(isMain).id`       |
/// | `ManagingProfiles(s)`         | `s.profiles.firstWhere(isMain).id`       |
///
/// In `ManagementPinRequired` and `ManagingProfiles`, the active profile
/// is **the main profile** (derived from the session's profile list, not
/// stored separately on the state). The spec
/// `profile-management` § "Enter profile management mode gated by main
/// profile PIN" guarantees these states are only reachable when a main
/// profile exists in the session, so `firstWhere(isMain)` does not need a
/// fallback — a missing main profile would be an orchestration bug, and
/// surfaces as `StateError` from `firstWhere`.
///
/// Primary consumer: the `AuthInterceptor` registered on `dioProvider`,
/// which uses this id to inject the `X-Profile-Id` header on protected
/// requests (everything except `/auth/*` and the bootstrap
/// `GET /profiles`).
///
/// The exhaustive `switch` over the sealed [SessionState] guarantees a
/// compile-time error if a new variant is added without updating this
/// mapping.

final class CurrentProfileIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Derived view over [SessionState]: the id of the profile considered
  /// **active** for outgoing HTTP requests, or `null` when no profile is
  /// active yet.
  ///
  /// Mapping over the seven [SessionState] variants:
  ///
  /// | Variant                       | Returned                                 |
  /// |-------------------------------|------------------------------------------|
  /// | `Anonymous`                   | `null`                                   |
  /// | `OtpRequested(...)`           | `null`                                   |
  /// | `Authenticated(session)`      | `null` (logged in, no profile picked yet) |
  /// | `PinRequired(profile, _)`     | `profile.id`                             |
  /// | `ProfileSelected(profile, _)` | `profile.id`                             |
  /// | `ManagementPinRequired(s)`    | `s.profiles.firstWhere(isMain).id`       |
  /// | `ManagingProfiles(s)`         | `s.profiles.firstWhere(isMain).id`       |
  ///
  /// In `ManagementPinRequired` and `ManagingProfiles`, the active profile
  /// is **the main profile** (derived from the session's profile list, not
  /// stored separately on the state). The spec
  /// `profile-management` § "Enter profile management mode gated by main
  /// profile PIN" guarantees these states are only reachable when a main
  /// profile exists in the session, so `firstWhere(isMain)` does not need a
  /// fallback — a missing main profile would be an orchestration bug, and
  /// surfaces as `StateError` from `firstWhere`.
  ///
  /// Primary consumer: the `AuthInterceptor` registered on `dioProvider`,
  /// which uses this id to inject the `X-Profile-Id` header on protected
  /// requests (everything except `/auth/*` and the bootstrap
  /// `GET /profiles`).
  ///
  /// The exhaustive `switch` over the sealed [SessionState] guarantees a
  /// compile-time error if a new variant is added without updating this
  /// mapping.
  CurrentProfileIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentProfileIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentProfileIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return currentProfileId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentProfileIdHash() => r'308319cceb2ff0effaba1e7224a995b5be60932c';
