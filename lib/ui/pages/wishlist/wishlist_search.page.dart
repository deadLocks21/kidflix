import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/wishlist_search_result.dto.dart';
import 'package:kidflix/core/application/usecases/search_addable_wishlist_content.usecase.dart';
import 'package:kidflix/infrastructure/providers/wishlist.usecases_provider.dart';
import 'package:kidflix/ui/pages/wishlist/widgets/wishlist_search_result_tile.widget.dart';

/// Full-screen search page for adding new entries to the foyer's
/// Watcharr wishlist. Opened from the FAB on [WishlistPage].
///
/// Debounce strategy: 350 ms idle after the last keystroke before
/// firing a query. Each new keystroke cancels the pending timer.
/// Queries shorter than 2 chars (post-trim) short-circuit to an
/// empty result list (matches
/// [SearchAddableWishlistContentUseCase.minQueryLength]).
class WishlistSearchPage extends ConsumerStatefulWidget {
  const WishlistSearchPage({super.key});

  @override
  ConsumerState<WishlistSearchPage> createState() => _WishlistSearchPageState();
}

class _WishlistSearchPageState extends ConsumerState<WishlistSearchPage> {
  static const Duration _debounce = Duration(milliseconds: 350);

  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;
  String _activeQuery = '';
  AsyncValue<List<WishlistSearchResultDto>> _results = const AsyncData([]);

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed == _activeQuery) return;
    _activeQuery = trimmed;
    if (trimmed.length < SearchAddableWishlistContentUseCase.minQueryLength) {
      setState(() => _results = const AsyncData([]));
      return;
    }
    setState(() => _results = const AsyncLoading());
    final result = await AsyncValue.guard(
      () => ref
          .read(searchAddableWishlistContentUseCaseProvider)
          .execute(trimmed),
    );
    if (!mounted) return;
    // Ignore the result if the user typed something else in the meantime.
    if (_activeQuery != trimmed) return;
    setState(() => _results = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter à la liste')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    onSubmitted: (v) {
                      _debounceTimer?.cancel();
                      _runSearch(v);
                    },
                    decoration: InputDecoration(
                      hintText: 'Rechercher un film ou une série…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _controller.clear();
                                _onChanged('');
                              },
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: _ResultsBody(query: _activeQuery, results: _results),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  final String query;
  final AsyncValue<List<WishlistSearchResultDto>> results;

  const _ResultsBody({required this.query, required this.results});

  @override
  Widget build(BuildContext context) {
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Error(message: '$e'),
      data: (list) {
        if (query.length < SearchAddableWishlistContentUseCase.minQueryLength) {
          return const _Hint(
            icon: Icons.search,
            message:
                'Tape au moins 2 caractères pour rechercher dans Watcharr.',
          );
        }
        if (list.isEmpty) {
          return _Hint(
            icon: Icons.sentiment_dissatisfied,
            message: 'Aucun résultat pour « $query ».',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          itemBuilder: (_, i) => WishlistSearchResultTile(
            key: ValueKey('${list[i].kind}-${list[i].tmdbId}'),
            result: list[i],
          ),
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String message;

  const _Hint({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.hintColor),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;

  const _Error({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Erreur de recherche',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}
