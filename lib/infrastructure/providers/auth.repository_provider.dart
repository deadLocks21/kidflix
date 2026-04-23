import 'package:kidflix/core/domain/services/auth.repository.dart';
import 'package:kidflix/infrastructure/auth/in_memory.auth.repository.dart';
import 'package:kidflix/infrastructure/providers/in_memory_accounts_store.provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth.repository_provider.g.dart';

/// Auth repository provider.
///
/// Currently always returns [InMemoryAuthRepository]. Will gain an HTTP
/// variant when the backend is available.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final pin = ref.watch(profilePinServiceProvider);
  final store = ref.watch(inMemoryAccountsStoreProvider);
  return InMemoryAuthRepository(pin, store);
}
