import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/search.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/search.usecase_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_detail_modal.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/search_result_tile.widget.dart';

/// Renders the search results area of the home page while search mode is
/// active. Switches between 5 states based on the controller and async
/// provider: below-minimum, loading, no-results, results, error.
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
          return _MessageState(text: 'Aucun film ne correspond à « $trimmed ».');
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => SearchResultTile(
            movie: list[i],
            onTap: () => _openDetail(context, ref, list[i]),
          ),
        );
      },
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    MovieDto movie,
  ) async {
    final repository = ref.read(catalogRepositoryProvider);
    final session = ref.read(sessionControllerProvider);
    if (session is! ProfileSelected) return;
    final category = AgeCategory.values.firstWhere(
      (c) => c.name == movie.ageCategory,
    );
    final pool = await repository.listMoviesFor(category);
    final domain = pool.firstWhere((m) => m.id == movie.id);
    if (!context.mounted) return;
    await showMovieDetailModal(context, MovieDetailDto.fromDomain(domain));
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
