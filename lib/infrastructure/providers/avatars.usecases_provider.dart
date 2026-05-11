import 'package:kidflix/core/application/dtos/avatar_option.dto.dart';
import 'package:kidflix/core/application/usecases/list_avatars.usecase.dart';
import 'package:kidflix/infrastructure/providers/avatars.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'avatars.usecases_provider.g.dart';

@Riverpod(keepAlive: true)
ListAvatarsUseCase listAvatarsUseCase(Ref ref) {
  return ListAvatarsUseCase(ref.watch(avatarsRepositoryProvider));
}

/// Cached server-side avatar catalogue, fetched once per app session.
///
/// `keepAlive: true` matches the `Cache-Control: max-age=3600` the server
/// publishes on `GET /avatars` — and goes further: a single fetch per app
/// run is enough since the whitelist only evolves at server release
/// boundaries. To force a refetch after a server release, restart the app.
@Riverpod(keepAlive: true)
Future<List<AvatarOptionDto>> avatarsList(Ref ref) {
  return ref.watch(listAvatarsUseCaseProvider).execute();
}
