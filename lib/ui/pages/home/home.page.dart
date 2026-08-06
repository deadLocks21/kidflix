import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:kidflix/infrastructure/providers/remote_catalog.provider.dart';
import 'package:kidflix/infrastructure/providers/search.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/focus/catalog_focus.dart';
import 'package:kidflix/ui/focus/kidflix_focus_zoom.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/catalog_row.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/catalog_skeleton.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/home_profile_menu.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_detail_modal.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/remote_control_button.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/search_app_bar.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/search_results.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/series_detail_modal.widget.dart';
import 'package:kidflix/ui/pages/remote/widgets/remote_movie_detail_modal.widget.dart';

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
    // While driving a host, the home shows the *host's* catalogue —
    // fetched from it, because the local account is not allowed to read
    // another account's profile. Its own rows are used otherwise.
    final drivingHost = ref.watch(viewingHostCatalogueProvider);
    final rows = drivingHost
        ? ref.watch(remoteHomeRowsProvider)
        : ref.watch(homeCatalogRowsProvider);
    final isSearching = ref.watch(
      searchUiControllerProvider.select((s) => s.active),
    );
    final online = ref
        .watch(connectivityProvider)
        .maybeWhen(data: (v) => v, orElse: () => true);
    return _SearchShortcuts(
      isSearching: isSearching,
      controller: ref.read(searchUiControllerProvider.notifier),
      child: _buildScaffold(
        context,
        ref,
        drivingHost: drivingHost,
        isSearching: isSearching,
        online: online,
        rows: rows,
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    WidgetRef ref, {
    required bool drivingHost,
    required bool isSearching,
    required bool online,
    required AsyncValue<List<CatalogRowDto>> rows,
  }) {
    return Scaffold(
      appBar: isSearching
          ? const SearchAppBar()
          : AppBar(
              title: Text(drivingHost ? 'Sur l’autre appareil' : 'Kidflix'),
              actions: [
                KidflixFocusZoom(
                  child: IconButton(
                    tooltip: 'Chercher un film',
                    icon: const Icon(Icons.search),
                    onPressed: () => ref
                        .read(searchUiControllerProvider.notifier)
                        .activate(),
                  ),
                ),
                const RemoteControlButton(),
                const HomeProfileMenu(),
                const SizedBox(width: 4),
              ],
            ),
      body: Column(
        children: [
          if (!online) const _OfflineBanner(),
          Expanded(
            // [IndexedStack] keeps both branches mounted to preserve
            // scroll position, and an unpainted branch is still
            // focusable — without [ExcludeFocus] the keyboard would walk
            // into invisible search results, and back into the catalog
            // while searching.
            child: IndexedStack(
              index: isSearching ? 1 : 0,
              children: [
                ExcludeFocus(
                  excluding: isSearching,
                  child: _HomeBody(
                    focusEnabled: !isSearching,
                    rows: rows,
                    onMovieTap: (movie) => drivingHost
                        ? _openRemoteMovieDetail(context, ref, movie)
                        : _openDetail(context, ref, movie),
                    onSeriesTap: (series) => drivingHost
                        ? _castSeriesUnsupported(context)
                        : _openSeriesDetail(context, ref, series),
                  ),
                ),
                ExcludeFocus(
                  excluding: !isSearching,
                  child: const SearchResults(),
                ),
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

  /// Opens the host's own detail for [movie] — fetched from the host —
  /// with a play button that casts. The local account cannot fetch this
  /// detail itself, so it is served over the socket like the rows.
  Future<void> _openRemoteMovieDetail(
    BuildContext context,
    WidgetRef ref,
    MovieDto movie,
  ) => showRemoteMovieDetailModal(context, movieId: movie.id);

  /// Casting a series from the remote is not wired yet — the host serves
  /// movie detail only. Saying so beats a card that does nothing.
  void _castSeriesUnsupported(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Les séries se lancent depuis l’appareil lui-même pour l’instant.',
        ),
      ),
    );
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

/// Keyboard access to search mode.
///
/// `/` goes through a [CharacterActivator] rather than a key activator so
/// it fires on any layout — on AZERTY the slash needs a modifier, and a
/// [SingleActivator] would never match.
///
/// `Escape` is bound here too, deeper than the app-wide "go back" mapping,
/// so closing the search takes precedence. Both actions report themselves
/// disabled when they have nothing to do, which hands the key back to the
/// layers above instead of swallowing it — that is how `/` still types a
/// slash inside the search field, and how `Escape` keeps doing nothing at
/// all on the home page.
class _SearchShortcuts extends StatelessWidget {
  final bool isSearching;
  final SearchUiController controller;
  final Widget child;

  const _SearchShortcuts({
    required this.isSearching,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        CharacterActivator('/'): _ToggleSearchIntent(open: true),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _ToggleSearchIntent(open: true),
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _ToggleSearchIntent(open: true),
        SingleActivator(LogicalKeyboardKey.escape): _ToggleSearchIntent(
          open: false,
        ),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ToggleSearchIntent: _ToggleSearchAction(
            controller: controller,
            isSearching: isSearching,
          ),
        },
        child: child,
      ),
    );
  }
}

class _ToggleSearchIntent extends Intent {
  final bool open;

  const _ToggleSearchIntent({required this.open});
}

class _ToggleSearchAction extends Action<_ToggleSearchIntent> {
  final SearchUiController controller;
  final bool isSearching;

  _ToggleSearchAction({required this.controller, required this.isSearching});

  @override
  bool isEnabled(_ToggleSearchIntent intent) => intent.open != isSearching;

  @override
  void invoke(_ToggleSearchIntent intent) =>
      intent.open ? controller.activate() : controller.deactivate();
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

  /// `false` while search mode owns the keyboard.
  final bool focusEnabled;

  const _HomeBody({
    required this.rows,
    required this.onMovieTap,
    required this.onSeriesTap,
    required this.focusEnabled,
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
              focusEnabled: focusEnabled,
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
  final bool focusEnabled;

  const _CatalogList({
    required this.rows,
    required this.onMovieTap,
    required this.onSeriesTap,
    required this.focusEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return CatalogFocusScope(
      enabled: focusEnabled,
      child: CustomScrollView(
        // One full row (320 dp of cards + label + spacing) beyond the
        // viewport, so a vertical keyboard move always finds the next row
        // already built — the focus coordinator can scroll *within* a row
        // to reach an unbuilt card, but it cannot conjure an unbuilt row.
        cacheExtent: 400,
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, i) => CatalogRowWidget(
              index: i,
              row: rows[i],
              onMovieTap: onMovieTap,
              onSeriesTap: onSeriesTap,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
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
            KidflixFocusZoom(
              child: OutlinedButton(
                onPressed: () => ref.invalidate(homeCatalogRowsProvider),
                child: const Text('Réessayer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
