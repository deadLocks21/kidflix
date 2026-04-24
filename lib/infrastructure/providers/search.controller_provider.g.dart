// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for the search bar on the home page.
///
/// Owns the debounce timing (250 ms) so the UI stays declarative. Use
/// [activate] / [deactivate] to toggle search mode, [updateQuery] on each
/// keystroke, and [clearQuery] to empty the field without leaving search
/// mode.

@ProviderFor(SearchUiController)
final searchUiControllerProvider = SearchUiControllerProvider._();

/// Controller for the search bar on the home page.
///
/// Owns the debounce timing (250 ms) so the UI stays declarative. Use
/// [activate] / [deactivate] to toggle search mode, [updateQuery] on each
/// keystroke, and [clearQuery] to empty the field without leaving search
/// mode.
final class SearchUiControllerProvider
    extends $NotifierProvider<SearchUiController, SearchUiState> {
  /// Controller for the search bar on the home page.
  ///
  /// Owns the debounce timing (250 ms) so the UI stays declarative. Use
  /// [activate] / [deactivate] to toggle search mode, [updateQuery] on each
  /// keystroke, and [clearQuery] to empty the field without leaving search
  /// mode.
  SearchUiControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchUiControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchUiControllerHash();

  @$internal
  @override
  SearchUiController create() => SearchUiController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchUiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchUiState>(value),
    );
  }
}

String _$searchUiControllerHash() =>
    r'4ef2a795dfd13501e5c9c300b1c457ab6ac058e1';

/// Controller for the search bar on the home page.
///
/// Owns the debounce timing (250 ms) so the UI stays declarative. Use
/// [activate] / [deactivate] to toggle search mode, [updateQuery] on each
/// keystroke, and [clearQuery] to empty the field without leaving search
/// mode.

abstract class _$SearchUiController extends $Notifier<SearchUiState> {
  SearchUiState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SearchUiState, SearchUiState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SearchUiState, SearchUiState>,
              SearchUiState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
