import 'package:kidflix/core/domain/services/profile_management.repository.dart';
import 'package:kidflix/infrastructure/profile_management/in_memory.profile_management.repository.dart';
import 'package:kidflix/infrastructure/providers/in_memory_accounts_store.provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_management.repository_provider.g.dart';

/// Profile-management repository provider.
///
/// Currently always returns [InMemoryProfileManagementRepository]. Will
/// gain an HTTP variant when the backend is available.
@Riverpod(keepAlive: true)
ProfileManagementRepository profileManagementRepository(Ref ref) {
  final store = ref.watch(inMemoryAccountsStoreProvider);
  final pin = ref.watch(profilePinServiceProvider);
  return InMemoryProfileManagementRepository(store, pin);
}
