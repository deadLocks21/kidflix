import 'package:kidflix/core/application/services/profile_management_application.service.dart';
import 'package:kidflix/core/application/usecases/change_main_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/change_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/clear_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/create_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/delete_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/enter_management_mode.usecase.dart';
import 'package:kidflix/core/application/usecases/update_profile_metadata.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_management_pin.usecase.dart';
import 'package:kidflix/infrastructure/providers/profile_management.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_management.service_provider.g.dart';

@Riverpod(keepAlive: true)
ProfileManagementApplicationService profileManagementService(Ref ref) {
  final repo = ref.watch(profileManagementRepositoryProvider);
  final pin = ref.watch(profilePinServiceProvider);
  return ProfileManagementApplicationService(
    enterManagementMode: const EnterManagementModeUseCase(),
    verifyManagementPin: VerifyManagementPinUseCase(pin),
    createProfile: CreateProfileUseCase(repo),
    updateProfileMetadata: UpdateProfileMetadataUseCase(repo),
    changeProfilePin: ChangeProfilePinUseCase(repo),
    clearProfilePin: ClearProfilePinUseCase(repo),
    changeMainProfilePin: ChangeMainProfilePinUseCase(repo),
    deleteProfile: DeleteProfileUseCase(repo),
  );
}
