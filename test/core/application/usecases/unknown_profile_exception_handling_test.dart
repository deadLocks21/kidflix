import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/change_main_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/change_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/clear_profile_pin.usecase.dart';
import 'package:kidflix/core/application/usecases/delete_profile.usecase.dart';
import 'package:kidflix/core/application/usecases/update_profile_metadata.usecase.dart';
import 'package:kidflix/core/domain/exceptions/unknown_profile.exception.dart';
import 'package:kidflix/core/domain/model/avatar_update.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/profile_management.repository.dart';

/// Defense-in-depth tests: when the repository throws
/// [UnknownProfileException] (e.g. the HTTP backend returned 404 because the
/// profile was deleted by another device between read and mutation), each
/// mutation usecase MUST map it to its existing `unknownProfile` result —
/// not propagate the raw exception to the UI.
void main() {
  final ar = const Profile(
    id: 'ar',
    name: 'Ar',
    ageCategory: AgeCategory.enfant,
    isMain: false,
  );
  final papa = const Profile(
    id: 'papa',
    name: 'Papa',
    ageCategory: AgeCategory.adulte,
    pinHash: r'$2b$12$abc',
    isMain: true,
  );
  final session = Session(
    jwt: 'eyJ',
    device: const Device(id: 'd1', name: null),
    profiles: [papa, ar],
  );

  test(
    'UpdateProfileMetadataUseCase maps UnknownProfileException to UnknownProfile result',
    () async {
      final usecase = UpdateProfileMetadataUseCase(
        _ThrowingRepository(UnknownProfileException('ar')),
      );

      final result = await usecase.execute(
        session: session,
        profileId: 'ar',
        rawName: 'Arthur',
        ageCategory: AgeCategory.ado,
      );

      expect(result, isA<UpdateProfileMetadataUnknownProfile>());
    },
  );

  test(
    'ChangeProfilePinUseCase maps UnknownProfileException to UnknownProfile result',
    () async {
      final usecase = ChangeProfilePinUseCase(
        _ThrowingRepository(UnknownProfileException('ar')),
      );

      final result = await usecase.execute(
        session: session,
        profileId: 'ar',
        rawPin: '1234',
      );

      expect(result, isA<ChangeProfilePinUnknownProfile>());
    },
  );

  test(
    'ClearProfilePinUseCase maps UnknownProfileException to UnknownProfile result',
    () async {
      final usecase = ClearProfilePinUseCase(
        _ThrowingRepository(UnknownProfileException('ar')),
      );

      final result = await usecase.execute(
        session: session,
        profileId: 'ar',
      );

      expect(result, isA<ClearProfilePinUnknownProfile>());
    },
  );

  test(
    'DeleteProfileUseCase maps UnknownProfileException to UnknownProfile result',
    () async {
      final usecase = DeleteProfileUseCase(
        _ThrowingRepository(UnknownProfileException('ar')),
      );

      final result = await usecase.execute(
        session: session,
        profileId: 'ar',
      );

      expect(result, isA<DeleteProfileUnknownProfile>());
    },
  );

  test(
    'ChangeMainProfilePinUseCase maps UnknownProfileException to its new variant',
    () async {
      final usecase = ChangeMainProfilePinUseCase(
        _ThrowingRepository(UnknownProfileException('papa')),
      );

      final result = await usecase.execute(
        session: session,
        newPin: '5678',
        confirmPin: '5678',
      );

      expect(result, isA<ChangeMainProfilePinUnknownProfile>());
    },
  );

  test(
    'Pre-check still short-circuits before any repo call when id is absent',
    () async {
      final repo = _ThrowingRepository(StateError('repo should not be called'));
      final usecase = UpdateProfileMetadataUseCase(repo);

      final result = await usecase.execute(
        session: session,
        profileId: 'ghost',
        rawName: 'X',
        ageCategory: AgeCategory.enfant,
      );

      expect(result, isA<UpdateProfileMetadataUnknownProfile>());
      expect(repo.calls, isEmpty);
    },
  );
}

class _ThrowingRepository implements ProfileManagementRepository {
  _ThrowingRepository(this._toThrow);

  final Object _toThrow;

  final List<String> calls = [];

  @override
  Future<Profile> create({
    required String name,
    required AgeCategory ageCategory,
    String? rawPin,
    String? avatarId,
  }) {
    calls.add('create');
    throw _toThrow;
  }

  @override
  Future<Profile> updateMetadata({
    required String id,
    required String name,
    required AgeCategory ageCategory,
    AvatarUpdate avatar = const AvatarUnchanged(),
  }) {
    calls.add('updateMetadata');
    throw _toThrow;
  }

  @override
  Future<Profile> updateIncludedLowerAgeCategories({
    required String id,
    required List<AgeCategory> categories,
  }) {
    calls.add('updateIncludedLowerAgeCategories');
    throw _toThrow;
  }

  @override
  Future<Profile> setPin({required String id, required String rawPin}) {
    calls.add('setPin');
    throw _toThrow;
  }

  @override
  Future<Profile> clearPin({required String id}) {
    calls.add('clearPin');
    throw _toThrow;
  }

  @override
  Future<void> delete({required String id}) {
    calls.add('delete');
    throw _toThrow;
  }
}
