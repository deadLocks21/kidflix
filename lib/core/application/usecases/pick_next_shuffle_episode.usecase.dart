import 'dart:math';

import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/core/domain/model/media.dart';

/// Picks the next episode for a series shuffle session.
///
/// Algorithm — shuffle-without-repetition:
/// 1. `candidates = flatRotationEpisodes(series) \ alreadyPlayedIds`
///    (Specials are already excluded by [flatRotationEpisodes]).
/// 2. Non-empty → return one uniformly at random.
/// 3. Empty → rotation exhausted: return one uniformly at random from
///    the full rotation, but try to avoid [currentEpisodeId] so the
///    user doesn't immediately re-play the episode they just finished
///    (only enforced when the rotation has more than one episode).
/// 4. Series has no rotation-eligible episode (Specials only) → `null`.
///
/// [random] is injected to keep tests deterministic. Defaults to
/// `Random()` when omitted.
Episode? pickNextShuffleEpisode({
  required Series series,
  required Set<String> alreadyPlayedIds,
  String? currentEpisodeId,
  Random? random,
}) {
  final all = flatRotationEpisodes(series);
  if (all.isEmpty) return null;

  final rng = random ?? Random();
  final candidates = all
      .where((e) => !alreadyPlayedIds.contains(e.id))
      .toList();
  if (candidates.isNotEmpty) {
    return candidates[rng.nextInt(candidates.length)];
  }

  if (all.length == 1) return all.first;
  final pool = all
      .where((e) => e.id != currentEpisodeId)
      .toList(growable: false);
  if (pool.isEmpty) return all[rng.nextInt(all.length)];
  return pool[rng.nextInt(pool.length)];
}
