import 'package:kidflix/core/application/usecases/logout.usecase.dart';
import 'package:kidflix/core/application/usecases/request_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/resend_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/restore_session.usecase.dart';
import 'package:kidflix/core/application/usecases/select_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_profile_pin.usecase.dart';

/// Bundle of all auth/profile-selection usecases, consumed by the session
/// controller in the infrastructure layer.
class AuthApplicationService {
  final RequestOtpUseCase requestOtp;
  final VerifyOtpUseCase verifyOtp;
  final ResendOtpUseCase resendOtp;
  final RestoreSessionUseCase restoreSession;
  final LogoutUseCase logout;
  final SelectProfileUseCase selectProfile;
  final VerifyProfilePinUseCase verifyProfilePin;

  const AuthApplicationService({
    required this.requestOtp,
    required this.verifyOtp,
    required this.resendOtp,
    required this.restoreSession,
    required this.logout,
    required this.selectProfile,
    required this.verifyProfilePin,
  });
}
