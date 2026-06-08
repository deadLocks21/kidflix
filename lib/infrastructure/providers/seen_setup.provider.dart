import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'seen_setup.provider.g.dart';

/// Full movie catalogue for the "déjà vu" bulk-entry screen — films only
/// (the feature is movie-scoped at MVP, like the "Jamais vus" row).
///
/// Not `keepAlive`: the list is only needed while the setup screen is
/// mounted and should re-fetch on each visit so a freshly-added
/// catalogue entry shows up.
@riverpod
Future<List<Movie>> seenSetupMovies(Ref ref) async {
  final catalog = await ref.watch(catalogRepositoryProvider).listCatalog();
  return catalog.whereType<Movie>().toList(growable: false);
}
