import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/search.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/search.usecase_provider.dart';
import 'package:kidflix/infrastructure/providers/series.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_detail_modal.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/search_result_tile.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/series_detail_modal.widget.dart';

/// Renders the search results area of the home page while search mode is
/// active. Switches between 5 states based on the controller and async
/// provider: below-minimum, loading, no-results, results, error.
///
/// Results may include both [MovieDto] and [SeriesDto] entries — the
/// search uses a hierarchical scope (`ageCategory ≤ active profile`)
/// server-side, so an `adulte` profile can find an `ado` series.
class SearchResults extends ConsumerWidget {
  const SearchResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchUiControllerProvider);
    final trimmed = state.debouncedQuery.trim();
    if (trimmed.length < 2) {
      return const _MessageState(
        text: 'Tape au moins 2 lettres pour chercher.',
      );
    }
    final results = ref.watch(searchResultsProvider(state.debouncedQuery));
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _ErrorState(
        onRetry: () =>
            ref.invalidate(searchResultsProvider(state.debouncedQuery)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return _MessageState(text: 'Aucun résultat ne correspond à « $trimmed ».');
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => SearchResultTile(
            item: list[i],
            onTap: () => _openDetail(context, ref, list[i]),
          ),
        );
      },
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    CatalogItemDto item,
  ) async {
    final session = ref.read(sessionControllerProvider);
    if (session is! ProfileSelected) return;

    if (item is MovieDto) {
      // Search results may include movies from categories other than the
      // active profile's (search scope is hierarchical) — re-issuing the
      // search lets us locate the full Movie regardless of category.
      final repository = ref.read(catalogRepositoryProvider);
      final pool = await repository.searchCatalog(query: item.title);
      final domain = pool
          .whereType<Movie>()
          .firstWhere((m) => m.id == item.id);
      if (!context.mounted) return;
      await showMovieDetailModal(context, MovieDetailDto.fromDomain(domain));
      return;
    }
    if (item is SeriesDto) {
      // For a series, we need a Domain Series (catalog projection) to
      // hand off to the modal. Re-issue the search to get it.
      final repository = ref.read(catalogRepositoryProvider);
      final pool = await repository.searchCatalog(query: item.title);
      final domain = pool
          .whereType<Series>()
          .firstWhere((s) => s.id == item.id);
      if (!context.mounted) return;
      // Modal will load the full hierarchy via seriesRepositoryProvider.
      ref.read(seriesRepositoryProvider);
      await showSeriesDetailModal(context, domain);
      return;
    }
  }
}

class _MessageState extends StatelessWidget {
  final String text;

  const _MessageState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Impossible de lancer la recherche.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
