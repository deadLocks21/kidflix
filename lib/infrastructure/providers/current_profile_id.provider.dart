import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_profile_id.provider.g.dart';

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
@Riverpod(keepAlive: true)
String? currentProfileId(Ref ref) {
  final state = ref.watch(sessionControllerProvider);
  return switch (state) {
    Anonymous() || OtpRequested() => null,
    Authenticated() => null,
    PinRequired(:final profile) => profile.id,
    ProfileSelected(:final profile) => profile.id,
    ManagementPinRequired(:final session) =>
      session.profiles.firstWhere((p) => p.isMain).id,
    ManagingProfiles(:final session) =>
      session.profiles.firstWhere((p) => p.isMain).id,
  };
}
