import 'package:kidflix/infrastructure/shared/in_memory_accounts.store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'in_memory_accounts_store.provider.g.dart';

/// Shared singleton-scoped store backing both [InMemoryAuthRepository] and
/// [InMemoryProfileManagementRepository] during the greenfield phase.
@Riverpod(keepAlive: true)
InMemoryAccountsStore inMemoryAccountsStore(Ref ref) {
  return InMemoryAccountsStore();
}
