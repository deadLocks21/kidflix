import 'package:kidflix/core/application/usecases/change_main_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/change_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/clear_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/create_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/delete_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/enter_management_mode.usecase.dart';
import 'package:kidflix/core/application/usecases/update_profile_metadata.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_management_pin.usecase.dart';

/// Bundle of all profile-management usecases, consumed by the session
/// controller in the infrastructure layer.
class ProfileManagementApplicationService {
  final EnterManagementModeUseCase enterManagementMode;
  final VerifyManagementPinUseCase verifyManagementPin;
  final CreateProfileUseCase createProfile;
  final UpdateProfileMetadataUseCase updateProfileMetadata;
  final ChangeProfilePinUseCase changeProfilePin;
  final ClearProfilePinUseCase clearProfilePin;
  final ChangeMainProfilePinUseCase changeMainProfilePin;
  final DeleteProfileUseCase deleteProfile;

  const ProfileManagementApplicationService({
    required this.enterManagementMode,
    required this.verifyManagementPin,
    required this.createProfile,
    required this.updateProfileMetadata,
    required this.changeProfilePin,
    required this.clearProfilePin,
    required this.changeMainProfilePin,
    required this.deleteProfile,
  });
}
