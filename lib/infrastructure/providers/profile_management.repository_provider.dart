import 'package:kidflix/core/domain/services/profile_management.repository.dart';
import 'package:kidflix/infrastructure/profile_management/dio.profile_management.repository.dart';
import 'package:kidflix/infrastructure/profile_management/in_memory.profile_management.repository.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/providers/in_memory_accounts_store.provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_management.repository_provider.g.dart';

/// Profile-management repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryProfileManagementRepository] — used by tests and
///   when no backend has been configured.
/// - **non-empty** → [DioProfileManagementRepository] consuming [dioProvider]
///   — talks to the real backend at the URL the user configured via the
///   ⚙ dialog on the phone-entry page (persisted in `shared_preferences`).
///
/// The selection MUST stay consistent with `authRepositoryProvider` —
/// both watch the same [apiBaseUrlProvider].
@Riverpod(keepAlive: true)
ProfileManagementRepository profileManagementRepository(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (isInMemoryBaseUrl(baseUrl)) {
    final store = ref.watch(inMemoryAccountsStoreProvider);
    final pin = ref.watch(profilePinServiceProvider);
    return InMemoryProfileManagementRepository(store, pin);
  }
  return DioProfileManagementRepository(ref.watch(dioProvider));
}
