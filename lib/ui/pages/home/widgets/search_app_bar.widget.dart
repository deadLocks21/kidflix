import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/infrastructure/providers/search.controller_provider.dart';
import 'package:kidflix/ui/focus/kidflix_focus_zoom.widget.dart';

/// Move the focus out of the query field and into the results list.
class _EnterResultsIntent extends Intent {
  const _EnterResultsIntent();
}

class _EnterResultsAction extends Action<_EnterResultsIntent> {
  @override
  void invoke(_EnterResultsIntent intent) {
    // Directional traversal, not a hard-wired node: the results live in a
    // different subtree, and "the focusable below the field" is exactly
    // the first result row — the inactive catalog branch of the
    // [IndexedStack] is excluded from focus while searching.
    FocusManager.instance.primaryFocus?.focusInDirection(
      TraversalDirection.down,
    );
  }
}

/// AppBar shown while the home page is in search mode.
///
/// Replaces the standard Kidflix AppBar with a close affordance, an
/// autofocused `TextField` and a conditional clear (`×`) action.
class SearchAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const SearchAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  ConsumerState<SearchAppBar> createState() => _SearchAppBarState();
}

class _SearchAppBarState extends ConsumerState<SearchAppBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchUiControllerProvider).rawQuery,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(searchUiControllerProvider);
    final controller = ref.read(searchUiControllerProvider.notifier);

    // Keep the TextField in sync when the controller is cleared externally.
    if (_controller.text != state.rawQuery) {
      _controller.value = TextEditingValue(
        text: state.rawQuery,
        selection: TextSelection.collapsed(offset: state.rawQuery.length),
      );
    }

    // Scoped to the app bar, so it only ever fires while the caret is in
    // the field. It has to sit here rather than on the page: further up,
    // `DefaultTextEditingShortcuts` claims the vertical arrows for caret
    // movement and the key would never reach us.
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowDown): _EnterResultsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _EnterResultsIntent: _EnterResultsAction(),
        },
        child: _buildAppBar(context, theme, state, controller),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ThemeData theme,
    SearchUiState state,
    SearchUiController controller,
  ) {
    return AppBar(
      leading: KidflixFocusZoom(
        child: IconButton(
          tooltip: 'Fermer la recherche',
          icon: const Icon(Icons.close),
          onPressed: controller.deactivate,
        ),
      ),
      title: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: controller.updateQuery,
        style: theme.textTheme.titleMedium,
        decoration: const InputDecoration(
          hintText: 'Chercher un film…',
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (state.rawQuery.isNotEmpty)
          KidflixFocusZoom(
            child: IconButton(
              tooltip: 'Effacer',
              icon: const Icon(Icons.clear),
              onPressed: controller.clearQuery,
            ),
          ),
      ],
    );
  }
}
