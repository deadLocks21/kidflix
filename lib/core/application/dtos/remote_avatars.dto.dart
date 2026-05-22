import 'package:kidflix/core/domain/model/avatar_option.dart';

/// Wire-format DTO for `GET /avatars` — direction `JSON → Domain` only.
///
/// JSON shape (per `API.md` §`GET /avatars`) :
/// ```json
/// { "avatars": [ { "id": "cat-01", "url": "/static/avatars/cat-01.svg" } ] }
/// ```
class RemoteAvatarsDto {
  final List<RemoteAvatarOption> avatars;

  const RemoteAvatarsDto({required this.avatars});

  factory RemoteAvatarsDto.fromJson(Map<String, dynamic> json) =>
      RemoteAvatarsDto(
        avatars: (json['avatars'] as List<dynamic>)
            .map((e) => RemoteAvatarOption.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  List<AvatarOption> toDomain() =>
      avatars.map((e) => e.toDomain()).toList(growable: false);
}

class RemoteAvatarOption {
  final String id;
  final String url;

  const RemoteAvatarOption({required this.id, required this.url});

  factory RemoteAvatarOption.fromJson(Map<String, dynamic> json) =>
      RemoteAvatarOption(id: json['id'] as String, url: json['url'] as String);

  AvatarOption toDomain() => AvatarOption(id: id, url: url);
}
