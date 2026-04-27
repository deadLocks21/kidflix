import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_session.provider.g.dart';

/// Derived view over [SessionState]: the [Session] currently established (if
/// any), or `null` for `Anonymous` / `OtpRequested`.
///
/// Consumed by the `AuthInterceptor` registered on `dioProvider` to read
/// `jwt` and `device.id` at every request, and reusable by any future
/// component that needs the active session without knowing the state machine
/// (logging, debug overlay, refresh interceptor…).
///
/// The exhaustive `switch` over the sealed [SessionState] guarantees a
/// compile-time error if a new variant is added without updating this
/// mapping.
@Riverpod(keepAlive: true)
Session? currentSession(Ref ref) {
  final state = ref.watch(sessionControllerProvider);
  return switch (state) {
    Authenticated(:final session) => session,
    PinRequired(:final session) => session,
    ProfileSelected(:final session) => session,
    ManagementPinRequired(:final session) => session,
    ManagingProfiles(:final session) => session,
    Anonymous() || OtpRequested() => null,
  };
}
