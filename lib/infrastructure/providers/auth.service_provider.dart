import 'package:kidflix/core/application/services/auth_application.service.dart';
import 'package:kidflix/core/application/usecases/logout.usecase.dart';
import 'package:kidflix/core/application/usecases/request_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/resend_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/restore_session.usecase.dart';
import 'package:kidflix/core/application/usecases/select_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_profile_pin.usecase.dart';
import 'package:kidflix/infrastructure/providers/auth.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/logger.service_provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:kidflix/infrastructure/providers/session.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth.service_provider.g.dart';

@Riverpod(keepAlive: true)
AuthApplicationService authService(Ref ref) {
  final auth = ref.watch(authRepositoryProvider);
  final sessions = ref.watch(sessionRepositoryProvider);
  final pin = ref.watch(profilePinServiceProvider);
  final logger = ref.watch(loggerProvider);
  return AuthApplicationService(
    requestOtp: RequestOtpUseCase(auth, logger),
    verifyOtp: VerifyOtpUseCase(auth, logger),
    resendOtp: ResendOtpUseCase(auth, logger),
    restoreSession: RestoreSessionUseCase(sessions, logger),
    logout: LogoutUseCase(sessions, logger),
    selectProfile: SelectProfileUseCase(logger),
    verifyProfilePin: VerifyProfilePinUseCase(pin, logger),
  );
}
