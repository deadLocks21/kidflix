import 'package:kidflix/core/domain/services/avatars.repository.dart';
import 'package:kidflix/infrastructure/avatars/dio.avatars.repository.dart';
import 'package:kidflix/infrastructure/avatars/in_memory.avatars.repository.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'avatars.repository_provider.g.dart';

/// Avatars catalogue repository provider.
///
/// Selects the implementation by the same `String.fromEnvironment('API_BASE_URL')`
/// flag used by `profileManagementRepositoryProvider` and `authRepositoryProvider`
/// — keep them consistent.
@Riverpod(keepAlive: true)
AvatarsRepository avatarsRepository(Ref ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) {
    return InMemoryAvatarsRepository();
  }
  return DioAvatarsRepository(ref.watch(dioProvider));
}
