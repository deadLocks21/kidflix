import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/remote/remote_catalog_codec.dart';
import 'package:kidflix/core/application/remote/remote_query.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/catalog.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/logger.service_provider.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_host_query_handler.g.dart';

/// Answers the data requests a remote makes of this host.
///
/// The remote asks because it *cannot* read this content itself: the
/// backend scopes every content route to the caller's own account, so a
/// remote signed into a different account than this host gets 403 for
/// this host's catalogue. This host can read it — under its own active
/// profile — and hands the result back.
///
/// It reuses the host's *own* [homeCatalogRowsProvider] and detail path,
/// so a remote sees byte-for-byte what the host's own home shows for the
/// active profile, filters and all.
@Riverpod(keepAlive: true)
RemoteHostQueryHandler remoteHostQueryHandler(Ref ref) =>
    RemoteHostQueryHandler(ref);

class RemoteHostQueryHandler {
  final Ref _ref;

  RemoteHostQueryHandler(this._ref);

  Future<void> handle(RemoteQuery query) async {
    final host = _ref.read(remoteControlHostProvider);
    try {
      final data = switch (query.kind) {
        RemoteQuery.kindHomeRows => await _homeRows(),
        RemoteQuery.kindMediaDetail => await _mediaDetail(query),
        _ => null,
      };
      if (data == null) {
        host.answerQuery(
          RemoteQueryResult.failure(
            query.queryId,
            code: 'unsupported',
            message: 'Requête non reconnue par cet appareil.',
          ),
        );
        return;
      }
      host.answerQuery(RemoteQueryResult.success(query.queryId, data));
    } catch (e, st) {
      _ref.read(loggerProvider).warn(
        'remote.host.query_failed',
        attrs: {'query.kind': query.kind},
        error: e,
        stack: st,
      );
      host.answerQuery(
        RemoteQueryResult.failure(
          query.queryId,
          code: 'query_failed',
          message: "L'appareil n'a pas pu récupérer les données.",
        ),
      );
    }
  }

  Future<Map<String, Object?>?> _homeRows() async {
    if (_ref.read(sessionControllerProvider) is! ProfileSelected) {
      // No active profile → nothing to serve. The remote already shows
      // its profile picker in this case, so this is belt-and-braces.
      return null;
    }
    final rows = await _ref.read(homeCatalogRowsProvider.future);
    return {'rows': [for (final row in rows) RemoteCatalogCodec.encodeRow(row)]};
  }

  Future<Map<String, Object?>?> _mediaDetail(RemoteQuery query) async {
    final mediaId = query.params['mediaId'];
    if (mediaId is! String) return null;
    // Series detail is not served yet — the remote only offers to cast a
    // movie from the detail sheet for now. Answering `unsupported` keeps
    // the door open without pretending.
    if (query.params['isSeries'] == true) return null;

    final pool = await _ref.read(catalogRepositoryProvider).listCatalog();
    final movie = pool
        .whereType<Movie>()
        .cast<Movie?>()
        .firstWhere((m) => m?.id == mediaId, orElse: () => null);
    if (movie == null) return null;
    return {
      'movie': RemoteCatalogCodec.encodeMovieDetail(
        MovieDetailDto.fromDomain(movie),
      ),
    };
  }
}
