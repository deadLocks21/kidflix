import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search.controller_provider.g.dart';

/// UI state for the inline search mode on the home page.
class SearchUiState {
  /// Whether search mode is currently active (AppBar replaced by search
  /// bar, body replaced by results).
  final bool active;

  /// Raw text currently in the `TextField`. Updated on every keystroke.
  final String rawQuery;

  /// Debounced version of [rawQuery], propagated after 250 ms of idle
  /// keyboard — this is the value that triggers an actual search.
  final String debouncedQuery;

  const SearchUiState({
    this.active = false,
    this.rawQuery = '',
    this.debouncedQuery = '',
  });

  SearchUiState copyWith({
    bool? active,
    String? rawQuery,
    String? debouncedQuery,
  }) => SearchUiState(
    active: active ?? this.active,
    rawQuery: rawQuery ?? this.rawQuery,
    debouncedQuery: debouncedQuery ?? this.debouncedQuery,
  );
}

/// Controller for the search bar on the home page.
///
/// Owns the debounce timing (250 ms) so the UI stays declarative. Use
/// [activate] / [deactivate] to toggle search mode, [updateQuery] on each
/// keystroke, and [clearQuery] to empty the field without leaving search
/// mode.
@riverpod
class SearchUiController extends _$SearchUiController {
  static const Duration _debounce = Duration(milliseconds: 250);

  Timer? _debounceTimer;

  @override
  SearchUiState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _debounceTimer = null;
    });
    return const SearchUiState();
  }

  void activate() {
    if (state.active) return;
    state = state.copyWith(active: true);
  }

  void deactivate() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    state = const SearchUiState();
  }

  void updateQuery(String raw) {
    state = state.copyWith(rawQuery: raw);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      state = state.copyWith(debouncedQuery: raw);
    });
  }

  void clearQuery() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    state = state.copyWith(rawQuery: '', debouncedQuery: '');
  }
}
