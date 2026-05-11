import 'package:kidflix/core/domain/model/avatar_option.dart';
import 'package:kidflix/core/domain/services/avatars.repository.dart';

/// InMemory implementation of [AvatarsRepository] used on web/tests.
///
/// Mirrors the server-side whitelist documented in `API.md` §`GET /avatars`.
/// In InMemory mode the PNG URLs are decorative — there is no server to
/// serve them — so the UI falls back to the letter placeholder.
class InMemoryAvatarsRepository implements AvatarsRepository {
  static const List<AvatarOption> _whitelist = [
    AvatarOption(id: 'cat-01', url: '/static/avatars/cat-01.png'),
    AvatarOption(id: 'panda-01', url: '/static/avatars/panda-01.png'),
    AvatarOption(id: 'fox-01', url: '/static/avatars/fox-01.png'),
    AvatarOption(id: 'owl-01', url: '/static/avatars/owl-01.png'),
    AvatarOption(id: 'rabbit-01', url: '/static/avatars/rabbit-01.png'),
    AvatarOption(id: 'tiger-01', url: '/static/avatars/tiger-01.png'),
    AvatarOption(id: 'frog-01', url: '/static/avatars/frog-01.png'),
    AvatarOption(id: 'dog-01', url: '/static/avatars/dog-01.png'),
  ];

  @override
  Future<List<AvatarOption>> list() async => _whitelist;
}
