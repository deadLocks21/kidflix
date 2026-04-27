import 'package:kidflix/core/domain/services/profile_management.repository.dart';
import 'package:kidflix/infrastructure/profile_management/dio.profile_management.repository.dart';
import 'package:kidflix/infrastructure/profile_management/in_memory.profile_management.repository.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/providers/in_memory_accounts_store.provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_management.repository_provider.g.dart';

/// Profile-management repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryProfileManagementRepository] — used by
///   tests, by `flutter run` without flag, and by anyone running offline.
/// - **non-empty** → [DioProfileManagementRepository] consuming [dioProvider]
///   — used to talk to the real backend, e.g.
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild. The selection MUST stay
/// consistent with `authRepositoryProvider` — they read the same flag.
@Riverpod(keepAlive: true)
ProfileManagementRepository profileManagementRepository(Ref ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) {
    final store = ref.watch(inMemoryAccountsStoreProvider);
    final pin = ref.watch(profilePinServiceProvider);
    return InMemoryProfileManagementRepository(store, pin);
  }
  return DioProfileManagementRepository(ref.watch(dioProvider));
}
