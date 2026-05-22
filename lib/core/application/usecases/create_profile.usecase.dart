import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/exceptions/invalid_profile_name.exception.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/profile_management.repository.dart';

/// Result of [CreateProfileUseCase.execute].
sealed class CreateProfileResult {
  const CreateProfileResult();
}

class CreateProfileSuccess extends CreateProfileResult {
  final Profile profile;

  const CreateProfileSuccess(this.profile);
}

class CreateProfileInvalidName extends CreateProfileResult {
  final InvalidProfileNameReason reason;

  const CreateProfileInvalidName(this.reason);
}

class CreateProfileInvalidPin extends CreateProfileResult {
  const CreateProfileInvalidPin();
}

class CreateProfileInvalidState extends CreateProfileResult {
  const CreateProfileInvalidState();
}

/// Validates a profile creation request and delegates persistence to the
/// [ProfileManagementRepository]. The returned profile always has
/// `isMain == false` — the main profile cannot be created from the app.
class CreateProfileUseCase {
  static const int _maxNameLength = 30;
  static final RegExp _pinPattern = RegExp(r'^[0-9]{4}$');

  final ProfileManagementRepository _repo;
  final LoggerApplicationService _logger;

  const CreateProfileUseCase(this._repo, this._logger);

  Future<CreateProfileResult> execute({
    required String rawName,
    required AgeCategory ageCategory,
    String? rawPin,
    String? avatarId,
  }) async {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return const CreateProfileInvalidName(InvalidProfileNameReason.empty);
    }
    if (trimmed.length > _maxNameLength) {
      return const CreateProfileInvalidName(InvalidProfileNameReason.tooLong);
    }
    if (rawPin != null && !_pinPattern.hasMatch(rawPin)) {
      return const CreateProfileInvalidPin();
    }
    try {
      final created = await _repo.create(
        name: trimmed,
        ageCategory: ageCategory,
        rawPin: rawPin,
        avatarId: avatarId,
      );
      await _logger.info(
        'profile.created',
        attrs: {'profile.id': created.id},
      );
      return CreateProfileSuccess(created);
    } catch (e, st) {
      await _logger.warn('profile.create_failed', error: e, stack: st);
      rethrow;
    }
  }
}
