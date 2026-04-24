import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/catalog.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/home/widgets/catalog_row.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/catalog_skeleton.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_detail_modal.widget.dart';

/// Homepage catalog: vertical scroll of horizontal rows built for the
/// active profile. Rows are filtered strictly by the profile's age
/// category; empty rows are hidden server-side (application service).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(homeCatalogRowsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kidflix'),
        actions: [
          IconButton(
            tooltip: 'Changer de profil',
            icon: const Icon(Icons.switch_account),
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).deselectProfile(),
          ),
        ],
      ),
      body: rows.when(
        loading: () => const CatalogSkeleton(),
        error: (_, _) => _ErrorState(
          onRetry: () => ref.invalidate(homeCatalogRowsProvider),
        ),
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : _CatalogList(
                rows: list,
                onMovieTap: (movie) => _openDetail(context, ref, movie),
              ),
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    MovieDto movie,
  ) async {
    final repository = ref.read(catalogRepositoryProvider);
    final state = ref.read(sessionControllerProvider);
    if (state is! ProfileSelected) return;
    final pool = await repository.listMoviesFor(state.profile.ageCategory);
    final domain = pool.firstWhere((m) => m.id == movie.id);
    if (!context.mounted) return;
    await showMovieDetailModal(context, MovieDetailDto.fromDomain(domain));
  }
}

class _CatalogList extends StatelessWidget {
  final List<CatalogRowDto> rows;
  final void Function(MovieDto movie) onMovieTap;

  const _CatalogList({required this.rows, required this.onMovieTap});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) => CatalogRowWidget(
            row: rows[i],
            onMovieTap: onMovieTap,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'Aucun film disponible pour ce profil pour le moment.',
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
              'Impossible de charger le catalogue.',
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
