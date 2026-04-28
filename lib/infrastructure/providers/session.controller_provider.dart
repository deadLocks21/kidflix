import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/change_main_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/change_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/clear_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/create_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/delete_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/enter_management_mode.usecase.dart';
import 'package:kidflix/core/application/usecases/request_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/resend_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/restore_session.usecase.dart';
import 'package:kidflix/core/application/usecases/select_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/update_profile_metadata.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_management_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_profile_pin.usecase.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/infrastructure/providers/auth.service_provider.dart';
import 'package:kidflix/infrastructure/providers/in_memory_accounts_store.provider.dart';
import 'package:kidflix/infrastructure/providers/profile_management.service_provider.dart';
import 'package:kidflix/infrastructure/providers/refresh_profiles.usecase_provider.dart';
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
    ref.read(inMemoryAccountsStoreProvider).clearCurrentAccount();
    state = const Anonymous();
  }

  // --- Profile management ---------------------------------------------------

  /// Enters management mode. On success, transitions to
  /// `ManagementPinRequired`. Fails if no profile has `isMain`.
  EnterManagementModeResult enterManagementMode() {
    final current = state;
    if (current is! Authenticated) {
      return const EnterManagementModeInvalidState();
    }
    final service = ref.read(profileManagementServiceProvider);
    final result = service.enterManagementMode.execute(
      session: current.session,
    );
    if (result is EnterManagementModeSuccess) {
      state = ManagementPinRequired(current.session);
    }
    return result;
  }

  Future<VerifyManagementPinResult> verifyManagementPin(String rawPin) async {
    final current = state;
    if (current is! ManagementPinRequired) {
      return const VerifyManagementPinInvalid();
    }
    final main = _mainProfile(current.session);
    if (main == null) return const VerifyManagementPinInvalid();
    final service = ref.read(profileManagementServiceProvider);
    final result = await service.verifyManagementPin.execute(
      mainProfile: main,
      rawPin: rawPin,
    );
    if (result is VerifyManagementPinSuccess) {
      state = ManagingProfiles(current.session);
    }
    return result;
  }

  void cancelManagementPinEntry() {
    final current = state;
    if (current is ManagementPinRequired) {
      state = Authenticated(current.session);
    }
  }

  void exitManagementMode() {
    final current = state;
    if (current is ManagingProfiles) {
      state = Authenticated(current.session);
    }
  }

  Future<CreateProfileResult> createProfile({
    required String name,
    required AgeCategory ageCategory,
    String? rawPin,
  }) async {
    final current = state;
    if (current is! ManagingProfiles) {
      return const CreateProfileInvalidState();
    }
    final service = ref.read(profileManagementServiceProvider);
    final result = await service.createProfile.execute(
      rawName: name,
      ageCategory: ageCategory,
      rawPin: rawPin,
    );
    if (result is CreateProfileSuccess) {
      final updatedProfiles = List<Profile>.from(current.session.profiles)
        ..add(result.profile);
      await _persistAndReplaceSession(
        current.session.copyWith(profiles: updatedProfiles),
      );
    }
    return result;
  }

  Future<UpdateProfileMetadataResult> updateProfileMetadata({
    required String profileId,
    required String name,
    required AgeCategory ageCategory,
  }) async {
    final current = state;
    if (current is! ManagingProfiles) {
      return const UpdateProfileMetadataInvalidState();
    }
    final service = ref.read(profileManagementServiceProvider);
    final result = await service.updateProfileMetadata.execute(
      session: current.session,
      profileId: profileId,
      rawName: name,
      ageCategory: ageCategory,
    );
    if (result is UpdateProfileMetadataSuccess) {
      await _persistAndReplaceSession(
        current.session.copyWith(
          profiles: _replaceProfile(current.session.profiles, result.profile),
        ),
      );
    }
    return result;
  }

  Future<ChangeProfilePinResult> changeProfilePin({
    required String profileId,
    required String rawPin,
  }) async {
    final current = state;
    if (current is! ManagingProfiles) {
      return const ChangeProfilePinInvalidState();
    }
    final service = ref.read(profileManagementServiceProvider);
    final result = await service.changeProfilePin.execute(
      session: current.session,
      profileId: profileId,
      rawPin: rawPin,
    );
    if (result is ChangeProfilePinSuccess) {
      await _persistAndReplaceSession(
        current.session.copyWith(
          profiles: _replaceProfile(current.session.profiles, result.profile),
        ),
      );
    }
    return result;
  }

  Future<ClearProfilePinResult> clearProfilePin({
    required String profileId,
  }) async {
    final current = state;
    if (current is! ManagingProfiles) {
      return const ClearProfilePinInvalidState();
    }
    final service = ref.read(profileManagementServiceProvider);
    final result = await service.clearProfilePin.execute(
      session: current.session,
      profileId: profileId,
    );
    if (result is ClearProfilePinSuccess) {
      await _persistAndReplaceSession(
        current.session.copyWith(
          profiles: _replaceProfile(current.session.profiles, result.profile),
        ),
      );
    }
    return result;
  }

  Future<ChangeMainProfilePinResult> changeMainProfilePin({
    required String newPin,
    required String confirmPin,
  }) async {
    final current = state;
    if (current is! ManagingProfiles) {
      return const ChangeMainProfilePinInvalidState();
    }
    final service = ref.read(profileManagementServiceProvider);
    final result = await service.changeMainProfilePin.execute(
      session: current.session,
      newPin: newPin,
      confirmPin: confirmPin,
    );
    if (result is ChangeMainProfilePinSuccess) {
      await _persistAndReplaceSession(
        current.session.copyWith(
          profiles: _replaceProfile(current.session.profiles, result.profile),
        ),
      );
    }
    return result;
  }

  Future<DeleteProfileResult> deleteProfile({required String profileId}) async {
    final current = state;
    if (current is! ManagingProfiles) {
      return const DeleteProfileInvalidState();
    }
    final service = ref.read(profileManagementServiceProvider);
    final result = await service.deleteProfile.execute(
      session: current.session,
      profileId: profileId,
    );
    if (result is DeleteProfileSuccess) {
      final updated = current.session.profiles
          .where((p) => p.id != profileId)
          .toList(growable: false);
      await _persistAndReplaceSession(
        current.session.copyWith(profiles: updated),
      );
    }
    return result;
  }

  /// Re-fetches the profile list from the backend (or the in-memory seed)
  /// and replaces `session.profiles` with the result. Used to resync after
  /// external mutations (new profile on another device, PIN updated,
  /// profile deleted). No automatic trigger is wired — UI callsites pick
  /// the right moment.
  ///
  /// Throws [StateError] when called from `Anonymous` or `OtpRequested`
  /// (no session to refresh) — the throw is delegated to
  /// [replaceProfiles].
  Future<void> refreshProfiles() async {
    final usecase = ref.read(refreshProfilesUseCaseProvider);
    final profiles = await usecase.execute();
    await replaceProfiles(profiles);
  }

  /// Replaces the profile list in the current session with [profiles] and
  /// persists the updated session via [sessionRepositoryProvider]. The
  /// `SessionState` variant is preserved (e.g. `ProfileSelected` stays
  /// `ProfileSelected`, with the same `profile` field even if that
  /// profile is no longer in the new list — recovery is deferred to a
  /// future change).
  ///
  /// Throws [StateError] if called from `Anonymous` or `OtpRequested`,
  /// where there is no session to refresh. Used by
  /// `RefreshProfilesUseCase` after `AuthRepository.fetchProfiles()`.
  Future<void> replaceProfiles(List<Profile> profiles) async {
    final current = state;
    final session = switch (current) {
      Authenticated(:final session) => session,
      PinRequired(:final session) => session,
      ProfileSelected(:final session) => session,
      ManagementPinRequired(:final session) => session,
      ManagingProfiles(:final session) => session,
      Anonymous() || OtpRequested() => null,
    };
    if (session == null || current is Anonymous || current is OtpRequested) {
      throw StateError(
        'replaceProfiles called from a state that carries no session: '
        '${current.runtimeType}',
      );
    }
    final next = session.copyWith(profiles: List.unmodifiable(profiles));
    await ref.read(sessionRepositoryProvider).write(next);
    state = switch (current) {
      Authenticated() => Authenticated(next),
      PinRequired(:final profile) =>
        PinRequired(profile: profile, session: next),
      ProfileSelected(:final profile) =>
        ProfileSelected(profile: profile, session: next),
      ManagementPinRequired() => ManagementPinRequired(next),
      ManagingProfiles() => ManagingProfiles(next),
      Anonymous() || OtpRequested() => current,
    };
  }

  Profile? _mainProfile(Session session) {
    for (final p in session.profiles) {
      if (p.isMain) return p;
    }
    return null;
  }

  List<Profile> _replaceProfile(List<Profile> profiles, Profile replacement) {
    return [
      for (final p in profiles)
        if (p.id == replacement.id) replacement else p,
    ];
  }

  Future<void> _persistAndReplaceSession(Session next) async {
    await ref.read(sessionRepositoryProvider).write(next);
    state = ManagingProfiles(next);
  }
}

/// Bootstrap provider: triggers [SessionController.restoreSession] at
/// app startup. The UI waits on this before building the router.
@Riverpod(keepAlive: true)
Future<void> bootstrap(Ref ref) async {
  await ref.read(sessionControllerProvider.notifier).restoreSession();
}
