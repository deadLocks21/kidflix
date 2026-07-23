import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/remote/remote_catalog_codec.dart';
import 'package:kidflix/core/application/remote/remote_query.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_catalog.provider.g.dart';

/// The host's active profile id, or null when not driving a ready host.
///
/// A derived primitive on purpose: the connection stream re-emits on
/// every position tick, but this value only changes when the host
/// actually switches profile — so Riverpod's equality check keeps
/// downstream fetches from rerunning once a second.
@riverpod
String? hostActiveProfileId(Ref ref) {
  final connection = ref.watch(remoteConnectionProvider).value;
  if (connection == null || !connection.isConnected) return null;
  final session = connection.playback.session;
  return session.isReady ? session.activeProfileId : null;
}

/// True while this device should show a host's catalogue instead of its
/// own: connected, and the host has an active profile to show one for.
///
/// When the host has no profile yet the remote shows its profile picker,
/// not a catalogue, so this stays false until the host is `ready`.
@riverpod
bool viewingHostCatalogue(Ref ref) =>
    ref.watch(hostActiveProfileIdProvider) != null;

/// The home rows of the host this device is driving, fetched from the
/// host over the socket.
///
/// This is the whole point of driving from a remote: you see the *host's*
/// catalogue — its active profile's rows, its age filter, its "Ma liste"
/// — not your own. The local account cannot fetch it (the backend 403s a
/// profile it does not own), so the host serves it.
///
/// Re-fetches whenever the host's active profile changes: the session
/// snapshot rides on every playback push, so watching the active profile
/// id reruns this the moment someone switches profile on the host.
@riverpod
Future<List<CatalogRowDto>> remoteHomeRows(Ref ref) async {
  // Rerun only when the host switches profile (or disconnects), not on
  // every position push — [hostActiveProfileId] dedups for us.
  final profileId = ref.watch(hostActiveProfileIdProvider);
  if (profileId == null) return const [];
  final client = ref.watch(remoteControlClientProvider);
  final data = await client.query(RemoteQuery.kindHomeRows);
  return RemoteCatalogCodec.decodeRows(data['rows']);
}

/// Full detail for one movie in the host's catalogue, fetched from the
/// host. Used by the remote's detail sheet, since the same 403 blocks the
/// local account from reading it directly.
@riverpod
Future<MovieDetailDto> remoteMovieDetail(Ref ref, String movieId) async {
  final client = ref.watch(remoteControlClientProvider);
  final data = await client.query(
    RemoteQuery.kindMediaDetail,
    params: {'mediaId': movieId, 'isSeries': false},
  );
  final movie = data['movie'];
  if (movie is! Map) {
    throw StateError('remote movie detail: unexpected payload');
  }
  return RemoteCatalogCodec.decodeMovieDetail(Map<String, Object?>.from(movie));
}
