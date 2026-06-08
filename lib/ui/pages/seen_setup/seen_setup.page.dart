import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/seen_mark.dart';
import 'package:kidflix/infrastructure/providers/seen.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/seen_setup.provider.dart';
import 'package:kidflix/shared/tmdb_image.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Bulk "déjà vu" entry screen.
///
/// Lists the whole movie catalogue grouped by saga then genre, each
/// section with a tri-state "select all". The active profile's existing
/// marks are pre-selected so the screen doubles as an editor. A single
/// "Enregistrer" commits the delta: additions go through the bulk
/// endpoint ([SeenController.markManySeen]), the rare removals through
/// unitary unmark.
class SeenSetupPage extends ConsumerStatefulWidget {
  const SeenSetupPage({super.key});

  @override
  ConsumerState<SeenSetupPage> createState() => _SeenSetupPageState();
}

class _SeenSetupPageState extends ConsumerState<SeenSetupPage> {
  /// Movie ids currently ticked. Seeded once from the profile's marks.
  final Set<String> _selected = {};

  /// The marks present when the screen opened — the baseline the save
  /// delta is computed against.
  Set<String> _initial = {};
  bool _seeded = false;
  String _query = '';
  bool _saving = false;

  void _seedIfNeeded(List<SeenMark> marks) {
    if (_seeded) return;
    _seeded = true;
    _initial = {for (final m in marks) m.movieId};
    _selected
      ..clear()
      ..addAll(_initial);
  }

  int get _changeCount =>
      _selected.difference(_initial).length +
      _initial.difference(_selected).length;

  @override
  Widget build(BuildContext context) {
    final asyncMovies = ref.watch(seenSetupMoviesProvider);
    final asyncSeen = ref.watch(seenControllerProvider);
    if (asyncSeen.hasValue) _seedIfNeeded(asyncSeen.value!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Films déjà vus'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher un film',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: asyncMovies.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Impossible de charger le catalogue.'),
            ),
          ),
          data: _buildList,
        ),
      ),
      bottomNavigationBar: _SaveBar(
        selectedCount: _selected.length,
        changeCount: _changeCount,
        saving: _saving,
        onSave: _save,
      ),
    );
  }

  Widget _buildList(List<Movie> movies) {
    final sections = _buildSections(movies);
    if (sections.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aucun film ne correspond à la recherche.'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Cochez les films déjà vus pour les retirer de « Jamais vus ».',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final section in sections) _SectionView(
          title: section.title,
          movies: section.movies,
          selected: _selected,
          onToggleMovie: _toggleMovie,
          onToggleSection: _toggleSection,
        ),
      ],
    );
  }

  void _toggleMovie(String movieId) {
    setState(() {
      if (!_selected.add(movieId)) _selected.remove(movieId);
    });
  }

  void _toggleSection(List<String> ids) {
    setState(() {
      final allSelected = ids.every(_selected.contains);
      if (allSelected) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  List<_Section> _buildSections(List<Movie> movies) {
    final q = _query.trim().toLowerCase();
    bool matches(Movie m) => q.isEmpty || m.title.toLowerCase().contains(q);

    final bySaga = <String, List<Movie>>{};
    final byGenre = <String, List<Movie>>{};
    final sagaLabels = <String, String>{};
    final others = <Movie>[];

    for (final m in movies.where(matches)) {
      if (m.hasSaga) {
        bySaga.putIfAbsent(m.sagaId!, () => []).add(m);
        sagaLabels[m.sagaId!] = m.sagaLabel ?? 'Saga';
      } else if (m.primaryGenre != null) {
        byGenre.putIfAbsent(m.primaryGenre!, () => []).add(m);
      } else {
        others.add(m);
      }
    }

    final sections = <_Section>[];
    final sagaKeys = bySaga.keys.toList()
      ..sort((a, b) => sagaLabels[a]!.compareTo(sagaLabels[b]!));
    for (final key in sagaKeys) {
      sections.add(_Section(title: sagaLabels[key]!, movies: bySaga[key]!));
    }
    final genreKeys = byGenre.keys.toList()..sort();
    for (final key in genreKeys) {
      sections.add(_Section(title: key, movies: byGenre[key]!));
    }
    if (others.isNotEmpty) {
      sections.add(_Section(title: 'Autres', movies: others));
    }
    return sections;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(seenControllerProvider.notifier);
    final toAdd = _selected.difference(_initial).toList();
    final toRemove = _initial.difference(_selected).toList();
    setState(() => _saving = true);
    try {
      if (toAdd.isNotEmpty) await controller.markManySeen(toAdd);
      for (final id in toRemove) {
        await controller.unmarkSeen(id);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Films déjà vus enregistrés')),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Échec de l\'enregistrement')),
      );
    }
  }
}

/// A catalogue grouping (one saga, one genre, or "Autres").
class _Section {
  final String title;
  final List<Movie> movies;

  const _Section({required this.title, required this.movies});
}

class _SectionView extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final Set<String> selected;
  final void Function(String movieId) onToggleMovie;
  final void Function(List<String> ids) onToggleSection;

  const _SectionView({
    required this.title,
    required this.movies,
    required this.selected,
    required this.onToggleMovie,
    required this.onToggleSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ids = movies.map((m) => m.id).toList(growable: false);
    final selectedCount = ids.where(selected.contains).length;
    final allSelected = selectedCount == ids.length && ids.isNotEmpty;
    final bool? checkboxValue = allSelected
        ? true
        : (selectedCount == 0 ? false : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              Text(
                '$selectedCount/${ids.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Checkbox(
                tristate: true,
                value: checkboxValue,
                onChanged: (_) => onToggleSection(ids),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final movie in movies)
              _PosterTile(
                movie: movie,
                selected: selected.contains(movie.id),
                onTap: () => onToggleMovie(movie.id),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PosterTile extends StatelessWidget {
  static const double width = 104;
  static const double posterHeight = 156;

  final Movie movie;
  final bool selected;
  final VoidCallback onTap;

  const _PosterTile({
    required this.movie,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: width,
                height: posterHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Poster(posterUrl: movie.posterUrl),
                    if (selected)
                      Container(
                        color: theme.colorScheme.primary.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.onPrimary,
                          size: 36,
                        ),
                      ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  final String? posterUrl;

  const _Poster({required this.posterUrl});

  @override
  Widget build(BuildContext context) {
    final url = posterUrl;
    if (url == null || url.isEmpty) return const _PosterFallback();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: tmdbResize(url, 'w185'),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      memCacheWidth: (_PosterTile.width * dpr).round(),
      placeholder: (_, _) => const ColoredBox(color: KidflixPalette.grey700),
      errorWidget: (_, _, _) => const _PosterFallback(),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: KidflixPalette.grey700,
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final int selectedCount;
  final int changeCount;
  final bool saving;
  final Future<void> Function() onSave;

  const _SaveBar({
    required this.selectedCount,
    required this.changeCount,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = changeCount > 0 && !saving;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$selectedCount film(s) déjà vu(s)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton(
              onPressed: enabled ? onSave : null,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
