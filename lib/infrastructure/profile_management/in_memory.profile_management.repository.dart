import 'package:kidflix/core/domain/exceptions/cannot_clear_main_profile_pin.exception.dart';
import 'package:kidflix/core/domain/exceptions/cannot_delete_main_profile.exception.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/profile_management.repository.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';
import 'package:kidflix/infrastructure/shared/in_memory_accounts.store.dart';
import 'package:uuid/uuid.dart';

/// InMemory implementation of [ProfileManagementRepository].
///
/// All mutations flow through [InMemoryAccountsStore] so that the auth
/// repository and the management repository share a single source of
/// truth. `create` targets the store's "current account" set by the auth
/// flow on successful OTP verification.
class InMemoryProfileManagementRepository
    implements ProfileManagementRepository {
  final InMemoryAccountsStore _store;
  final ProfilePinService _pin;
  final Uuid _uuid;

  InMemoryProfileManagementRepository(
    this._store,
    this._pin, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  @override
  Future<Profile> create({
    required String name,
    required AgeCategory ageCategory,
    String? rawPin,
  }) async {
    final account = _store.currentAccount;
    if (account == null) {
      throw StateError(
        'InMemoryProfileManagementRepository.create called without a '
        'current account set on the store — did the session flow set it?',
      );
    }
    final pinHash = rawPin == null ? null : await _pin.hash(rawPin);
    final created = Profile(
      id: _uuid.v4(),
      name: name,
      ageCategory: ageCategory,
      pinHash: pinHash,
    );
    account.profiles.add(created);
    return created;
  }

  @override
  Future<Profile> updateMetadata({
    required String id,
    required String name,
    required AgeCategory ageCategory,
  }) async {
    final (account, index) = _locate(id);
    final existing = account.profiles[index];
    final updated = Profile(
      id: existing.id,
      name: name,
      ageCategory: ageCategory,
      pinHash: existing.pinHash,
      avatarUrl: existing.avatarUrl,
      isMain: existing.isMain,
    );
    account.profiles[index] = updated;
    return updated;
  }

  @override
  Future<Profile> setPin({required String id, required String rawPin}) async {
    final hash = await _pin.hash(rawPin);
    final (account, index) = _locate(id);
    final existing = account.profiles[index];
    final updated = Profile(
      id: existing.id,
      name: existing.name,
      ageCategory: existing.ageCategory,
      pinHash: hash,
      avatarUrl: existing.avatarUrl,
      isMain: existing.isMain,
    );
    account.profiles[index] = updated;
    return updated;
  }

  @override
  Future<Profile> clearPin({required String id}) async {
    final (account, index) = _locate(id);
    final existing = account.profiles[index];
    if (existing.isMain) {
      throw CannotClearMainProfilePinException(id);
    }
    final updated = Profile(
      id: existing.id,
      name: existing.name,
      ageCategory: existing.ageCategory,
      pinHash: null,
      avatarUrl: existing.avatarUrl,
      isMain: existing.isMain,
    );
    account.profiles[index] = updated;
    return updated;
  }

  @override
  Future<void> delete({required String id}) async {
    final (account, index) = _locate(id);
    final existing = account.profiles[index];
    if (existing.isMain) {
      throw CannotDeleteMainProfileException(id);
    }
    account.profiles.removeAt(index);
  }

  (InMemoryAccount, int) _locate(String profileId) {
    final account = _store.findAccountContaining(profileId);
    if (account == null) {
      throw StateError('Profile "$profileId" not found in any account');
    }
    final index = account.profiles.indexWhere((p) => p.id == profileId);
    return (account, index);
  }
}
