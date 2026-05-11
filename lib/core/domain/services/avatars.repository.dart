import 'package:kidflix/core/domain/model/avatar_option.dart';

/// Read-only access to the server-side avatar catalogue (`GET /avatars`).
///
/// Endpoint is **public** — no auth, no `X-Device-Id`, no `X-Profile-Id`.
/// The catalogue evolves only at server release boundaries; the client
/// caches it locally for the session (cf. the `avatarsListProvider`
/// `FutureProvider` in `lib/infrastructure/providers/`).
///
/// Implementations live in `lib/infrastructure/avatars/`:
/// - [DioAvatarsRepository] for HTTP.
/// - [InMemoryAvatarsRepository] for web/tests, mirrors the server
///   whitelist hardcoded at compile time.
abstract interface class AvatarsRepository {
  /// Returns the catalogue, in server-stable order.
  Future<List<AvatarOption>> list();
}
