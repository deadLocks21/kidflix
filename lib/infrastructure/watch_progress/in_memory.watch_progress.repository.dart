import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

/// RAM-only [WatchProgressRepository] used until the backend lands.
///
/// Entries are lost at app restart — acceptable for MVP. The HTTP
/// replacement will preserve the same contract.
class InMemoryWatchProgressRepository implements WatchProgressRepository {
  final Map<String, WatchProgress> _store = {};

  String _key(String profileId, String movieId) => '$profileId|$movieId';

  @override
  Future<WatchProgress?> findFor({
    required String profileId,
    required String movieId,
  }) async {
    return _store[_key(profileId, movieId)];
  }

  @override
  Future<void> save(WatchProgress progress) async {
    _store[_key(progress.profileId, progress.movieId)] = progress;
  }

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async {
    return _store.values
        .where((p) => p.profileId == profileId)
        .toList(growable: false);
  }
}
