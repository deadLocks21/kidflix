import 'package:kidflix/core/domain/services/auth.repository.dart';
import 'package:kidflix/infrastructure/auth/dio.auth.repository.dart';
import 'package:kidflix/infrastructure/auth/in_memory.auth.repository.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/providers/in_memory_accounts_store.provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth.repository_provider.g.dart';

/// Auth repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryAuthRepository] — used by tests and when no
///   backend has been configured.
/// - **non-empty** → [DioAuthRepository] consuming [dioProvider] — talks
///   to the real backend at the URL configured by the user via the ⚙
///   dialog on the phone-entry page (persisted in `shared_preferences`).
///
/// The URL changes at runtime invalidate this provider via the
/// `ref.watch` below, so the next call uses the freshly built repository.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (baseUrl.isEmpty) {
    final pin = ref.watch(profilePinServiceProvider);
    final store = ref.watch(inMemoryAccountsStoreProvider);
    return InMemoryAuthRepository(pin, store);
  }
  return DioAuthRepository(ref.watch(dioProvider));
}
