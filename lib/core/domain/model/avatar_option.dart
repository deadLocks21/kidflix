/// One entry of the server-side avatar catalogue (`GET /avatars`).
///
/// [id] is a stable opaque identifier (regex `^[a-z0-9-]+$`) sent in
/// `POST/PATCH /profiles { avatar_id: ... }` and persisted as
/// `Profile.avatarId`.
///
/// [url] is a path **relative** to the API base URL, ex.
/// `/static/avatars/cat-01.png`. The UI concatenates it with the base URL
/// before passing to `CachedNetworkImage` — the domain stays free of
/// transport concerns.
class AvatarOption {
  final String id;
  final String url;

  const AvatarOption({required this.id, required this.url});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AvatarOption && other.id == id && other.url == url);

  @override
  int get hashCode => Object.hash(id, url);

  @override
  String toString() => 'AvatarOption(id: $id, url: $url)';
}
