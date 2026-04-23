import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/request_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/resend_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/restore_session.usecase.dart';
import 'package:kidflix/core/application/usecases/select_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_profile_pin.usecase.dart';
import 'package:kidflix/infrastructure/providers/auth.service_provider.dart';
import 'package:kidflix/infrastructure/providers/session.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session.controller_provider.g.dart';

/// Central controller for [SessionState]. Single point of contact between
/// the UI and the application layer.
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  @override
  SessionState build() => const Anonymous();

  /// Reads any persisted session and updates state accordingly. Called
  /// once at app startup by [bootstrapProvider].
  Future<void> restoreSession() async {
    final service = ref.read(authServiceProvider);
    final result = await service.restoreSession.execute();
    switch (result) {
      case RestoreSessionFound(:final session):
        state = Authenticated(session);
      case RestoreSessionNone():
        state = const Anonymous();
    }
  }

  Future<RequestOtpResult> requestOtp(String rawPhone) async {
    final service = ref.read(authServiceProvider);
    final result = await service.requestOtp.execute(rawPhone);
    if (result is RequestOtpSuccess) {
      state = OtpRequested(phone: result.phone, expiresAt: result.expiresAt);
    }
    return result;
  }

  Future<ResendOtpResult> resendOtp() async {
    final current = state;
    if (current is! OtpRequested) {
      return const ResendOtpUnknownPhone();
    }
    final service = ref.read(authServiceProvider);
    final result = await service.resendOtp.execute(current.phone);
    if (result is ResendOtpSuccess) {
      state = OtpRequested(phone: current.phone, expiresAt: result.expiresAt);
    }
    return result;
  }

  Future<VerifyOtpResult> verifyOtp(String rawCode) async {
    final current = state;
    if (current is! OtpRequested) {
      return const VerifyOtpInvalidCode();
    }
    final service = ref.read(authServiceProvider);
    final sessions = ref.read(sessionRepositoryProvider);
    final device = await sessions.readOrCreateDevice();
    final result = await service.verifyOtp.execute(
      phone: current.phone,
      rawCode: rawCode,
      device: device,
    );
    if (result is VerifyOtpSuccess) {
      await sessions.write(result.session);
      state = Authenticated(result.session);
    }
    return result;
  }

  /// Replays an OTP request for the same phone (used when the previous
  /// one expired). Same cooldown rules apply UI-side.
  Future<void> resetToPhoneEntry() async {
    state = const Anonymous();
  }

  /// Intended for use from the phone entry screen when the user wants
  /// to change the phone after a wrong number was entered.
  void backToPhoneEntry() {
    if (state is OtpRequested) {
      state = const Anonymous();
    }
  }

  Future<SelectProfileResult> selectProfile(String profileId) async {
    final current = state;
    if (current is! Authenticated && current is! ProfileSelected) {
      return const SelectProfileUnknown();
    }
    final service = ref.read(authServiceProvider);
    final session = switch (current) {
      Authenticated(:final session) => session,
      ProfileSelected(:final session) => session,
      _ => throw StateError('Unreachable'),
    };
    final result = service.selectProfile.execute(
      session: session,
      profileId: profileId,
    );
    switch (result) {
      case SelectProfileReady(:final profile):
        state = ProfileSelected(profile: profile, session: session);
      case SelectProfilePinRequired(:final profile):
        state = PinRequired(profile: profile, session: session);
      case SelectProfileUnknown():
        break;
    }
    return result;
  }

  Future<VerifyProfilePinResult> verifyPin(String rawPin) async {
    final current = state;
    if (current is! PinRequired) {
      return const VerifyProfilePinInvalid();
    }
    final service = ref.read(authServiceProvider);
    final result = await service.verifyProfilePin.execute(
      profile: current.profile,
      rawPin: rawPin,
    );
    if (result is VerifyProfilePinSuccess) {
      state = ProfileSelected(
        profile: current.profile,
        session: current.session,
      );
    }
    return result;
  }

  void cancelPinEntry() {
    final current = state;
    if (current is PinRequired) {
      state = Authenticated(current.session);
    }
  }

  /// Returns to the profile selection screen without clearing the session.
  /// Used by the "Changer de profil" action on the home page.
  void deselectProfile() {
    final current = state;
    if (current is ProfileSelected) {
      state = Authenticated(current.session);
    }
  }

  Future<void> logout() async {
    final service = ref.read(authServiceProvider);
    await service.logout.execute();
    state = const Anonymous();
  }
}

/// Bootstrap provider: triggers [SessionController.restoreSession] at
/// app startup. The UI waits on this before building the router.
@Riverpod(keepAlive: true)
Future<void> bootstrap(Ref ref) async {
  await ref.read(sessionControllerProvider.notifier).restoreSession();
}
