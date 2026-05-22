import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/exceptions/cannot_delete_main_profile.exception.dart';
import 'package:kidflix/core/domain/exceptions/unknown_profile.exception.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/profile_management.repository.dart';

/// Result of [DeleteProfileUseCase.execute].
sealed class DeleteProfileResult {
  const DeleteProfileResult();
}

class DeleteProfileSuccess extends DeleteProfileResult {
  const DeleteProfileSuccess();
}

class DeleteProfileUnknownProfile extends DeleteProfileResult {
  const DeleteProfileUnknownProfile();
}

class DeleteProfileCannotDeleteMain extends DeleteProfileResult {
  const DeleteProfileCannotDeleteMain();
}

class DeleteProfileInvalidState extends DeleteProfileResult {
  const DeleteProfileInvalidState();
}

/// Deletes a standard profile. The Domain enforces the "main profile is
/// indestructible" rule; this usecase catches that exception and maps it
/// to a UI-ready failure flag.
class DeleteProfileUseCase {
  final ProfileManagementRepository _repo;
  final LoggerApplicationService _logger;

  const DeleteProfileUseCase(this._repo, this._logger);

  Future<DeleteProfileResult> execute({
    required Session session,
    required String profileId,
  }) async {
    final exists = session.profiles.any((p) => p.id == profileId);
    if (!exists) return const DeleteProfileUnknownProfile();
    try {
      await _repo.delete(id: profileId);
      await _logger.info('profile.deleted', attrs: {'profile.id': profileId});
      return const DeleteProfileSuccess();
    } on CannotDeleteMainProfileException catch (e, st) {
      await _logger.warn('profile.delete_failed', error: e, stack: st);
      return const DeleteProfileCannotDeleteMain();
    } on UnknownProfileException catch (e, st) {
      await _logger.warn('profile.delete_failed', error: e, stack: st);
      return const DeleteProfileUnknownProfile();
    }
  }
}
