import 'package:kidflix/core/domain/services/auth.repository.dart';
import 'package:kidflix/infrastructure/auth/dio.auth.repository.dart';
import 'package:kidflix/infrastructure/auth/in_memory.auth.repository.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/providers/in_memory_accounts_store.provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth.repository_provider.g.dart';

/// Auth repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryAuthRepository] — used by tests, by
///   `flutter run` without flag, and by anyone running offline.
/// - **non-empty** → [DioAuthRepository] consuming [dioProvider] — used to
///   talk to the real backend, e.g.
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) {
    final pin = ref.watch(profilePinServiceProvider);
    final store = ref.watch(inMemoryAccountsStoreProvider);
    return InMemoryAuthRepository(pin, store);
  }
  return DioAuthRepository(ref.watch(dioProvider));
}
