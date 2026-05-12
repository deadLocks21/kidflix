import 'package:kidflix/core/domain/services/avatars.repository.dart';
import 'package:kidflix/infrastructure/avatars/dio.avatars.repository.dart';
import 'package:kidflix/infrastructure/avatars/in_memory.avatars.repository.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'avatars.repository_provider.g.dart';

/// Avatars catalogue repository provider.
///
/// Selects the implementation by reading [apiBaseUrlProvider] — same source
/// used by `profileManagementRepositoryProvider` and `authRepositoryProvider`,
/// so all three stay consistent when the user switches backend.
@Riverpod(keepAlive: true)
AvatarsRepository avatarsRepository(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (isInMemoryBaseUrl(baseUrl)) {
    return InMemoryAvatarsRepository();
  }
  return DioAvatarsRepository(ref.watch(dioProvider));
}
