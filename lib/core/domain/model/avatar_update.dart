/// Tri-state update for the `avatar_id` field on `PATCH /profiles/{id}`.
///
/// Mirrors the wire contract documented in `API.md` §`PATCH /profiles/{id}`:
/// - [AvatarUnchanged]      → key absent from request body, server keeps current value.
/// - [AvatarSetTo]          → string value, server sets the avatar.
/// - [AvatarClear]          → explicit `null`, server clears the avatar.
sealed class AvatarUpdate {
  const AvatarUpdate();
}

class AvatarUnchanged extends AvatarUpdate {
  const AvatarUnchanged();
}

class AvatarSetTo extends AvatarUpdate {
  final String avatarId;
  const AvatarSetTo(this.avatarId);
}

class AvatarClear extends AvatarUpdate {
  const AvatarClear();
}
