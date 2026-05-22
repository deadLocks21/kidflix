import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/catalog.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/connectivity.service_provider.dart';
import 'package:kidflix/infrastructure/providers/offline_catalog.service_provider.dart';
import 'package:kidflix/infrastructure/providers/search.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/home/widgets/catalog_row.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/catalog_skeleton.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/home_profile_menu.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_detail_modal.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/search_app_bar.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/search_results.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/series_detail_modal.widget.dart';

/// Homepage catalog: vertical scroll of horizontal rows built for the
/// active profile. Rows are filtered strictly by the profile's age
/// category; empty rows are hidden server-side (application service).
///
/// Hosts the inline search mode — a search icon in the AppBar swaps the
/// header for a search bar and the body for the search results (via
/// [IndexedStack] to preserve scroll position and results between
/// toggles).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(homeCatalogRowsProvider);
    final isSearching = ref.watch(
      searchUiControllerProvider.select((s) => s.active),
    );
    final online = ref
        .watch(connectivityProvider)
        .maybeWhen(data: (v) => v, orElse: () => true);
    return Scaffold(
      appBar: isSearching
          ? const SearchAppBar()
          : AppBar(
              title: const Text('Kidflix'),
              actions: [
                IconButton(
                  tooltip: 'Chercher un film',
                  icon: const Icon(Icons.search),
                  onPressed: () =>
                      ref.read(searchUiControllerProvider.notifier).activate(),
                ),
                const HomeProfileMenu(),
                const SizedBox(width: 4),
              ],
            ),
      body: Column(
        children: [
          if (!online) const _OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: isSearching ? 1 : 0,
              children: [
                _HomeBody(
                  rows: rows,
                  onMovieTap: (movie) => _openDetail(context, ref, movie),
                  onSeriesTap: (series) =>
                      _openSeriesDetail(context, ref, series),
                ),
                const SearchResults(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    MovieDto movie,
  ) async {
    final state = ref.read(sessionControllerProvider);
    if (state is! ProfileSelected) return;
    final online = ref.read(connectivityServiceProvider).isOnline;
    final repository = online
        ? ref.read(catalogRepositoryProvider)
        : ref.read(offlineCatalogRepositoryProvider);
    Movie? domain;
    try {
      final pool = await repository.listCatalog();
      domain = pool.whereType<Movie>().cast<Movie?>().firstWhere(
        (m) => m?.id == movie.id,
        orElse: () => null,
      );
    } catch (_) {
      // Network failure while nominally online — try the offline source
      // so the modal still opens for a downloaded movie.
      final pool = await ref
          .read(offlineCatalogRepositoryProvider)
          .listCatalog();
      domain = pool.whereType<Movie>().cast<Movie?>().firstWhere(
        (m) => m?.id == movie.id,
        orElse: () => null,
      );
    }
    if (domain == null) return;
    if (!context.mounted) return;
    await showMovieDetailModal(context, MovieDetailDto.fromDomain(domain));
  }

  Future<void> _openSeriesDetail(
    BuildContext context,
    WidgetRef ref,
    SeriesDto series,
  ) async {
    final state = ref.read(sessionControllerProvider);
    if (state is! ProfileSelected) return;
    final online = ref.read(connectivityServiceProvider).isOnline;
    final repository = online
        ? ref.read(catalogRepositoryProvider)
        : ref.read(offlineCatalogRepositoryProvider);
    Series? domain;
    try {
      final pool = await repository.listCatalog();
      domain = pool.whereType<Series>().cast<Series?>().firstWhere(
        (s) => s?.id == series.id,
        orElse: () => null,
      );
    } catch (_) {
      // Network failure while nominally online — fall back to the
      // manifest so a downloaded series still opens.
      final pool = await ref
          .read(offlineCatalogRepositoryProvider)
          .listCatalog();
      domain = pool.whereType<Series>().cast<Series?>().firstWhere(
        (s) => s?.id == series.id,
        orElse: () => null,
      );
    }
    if (domain == null) return;
    if (!context.mounted) return;
    await showSeriesDetailModal(context, domain);
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                size: 20,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hors ligne — seuls les films téléchargés sont disponibles.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final AsyncValue<List<CatalogRowDto>> rows;
  final void Function(MovieDto movie) onMovieTap;
  final void Function(SeriesDto series) onSeriesTap;

  const _HomeBody({
    required this.rows,
    required this.onMovieTap,
    required this.onSeriesTap,
  });

  @override
  Widget build(BuildContext context) {
    // When the provider refreshes (e.g. invalidated after a download
    // starts), we keep showing the previous list rather than flashing
    // back to the skeleton — otherwise the ListView gets torn down and
    // the user loses their scroll position.
    if (rows.hasValue) {
      final list = rows.value!;
      return list.isEmpty
          ? const _EmptyState()
          : _CatalogList(
              rows: list,
              onMovieTap: onMovieTap,
              onSeriesTap: onSeriesTap,
            );
    }
    if (rows.hasError) return const _ErrorState();
    return const CatalogSkeleton();
  }
}

class _CatalogList extends StatelessWidget {
  final List<CatalogRowDto> rows;
  final void Function(MovieDto movie) onMovieTap;
  final void Function(SeriesDto series) onSeriesTap;

  const _CatalogList({
    required this.rows,
    required this.onMovieTap,
    required this.onSeriesTap,
  });

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
            onSeriesTap: onSeriesTap,
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

class _ErrorState extends ConsumerWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            OutlinedButton(
              onPressed: () => ref.invalidate(homeCatalogRowsProvider),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
