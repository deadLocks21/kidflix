import 'package:kidflix/core/application/services/auth_application.service.dart';
import 'package:kidflix/core/application/usecases/logout.usecase.dart';
import 'package:kidflix/core/application/usecases/request_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/resend_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/restore_session.usecase.dart';
import 'package:kidflix/core/application/usecases/select_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_profile_pin.usecase.dart';
import 'package:kidflix/infrastructure/providers/auth.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:kidflix/infrastructure/providers/session.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth.service_provider.g.dart';

@Riverpod(keepAlive: true)
AuthApplicationService authService(Ref ref) {
  final auth = ref.watch(authRepositoryProvider);
  final sessions = ref.watch(sessionRepositoryProvider);
  final pin = ref.watch(profilePinServiceProvider);
  return AuthApplicationService(
    requestOtp: RequestOtpUseCase(auth),
    verifyOtp: VerifyOtpUseCase(auth),
    resendOtp: ResendOtpUseCase(auth),
    restoreSession: RestoreSessionUseCase(sessions),
    logout: LogoutUseCase(sessions),
    selectProfile: const SelectProfileUseCase(),
    verifyProfilePin: VerifyProfilePinUseCase(pin),
  );
}
