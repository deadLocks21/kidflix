import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/infrastructure/providers/search.controller_provider.dart';

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

    return AppBar(
      leading: IconButton(
        tooltip: 'Fermer la recherche',
        icon: const Icon(Icons.close),
        onPressed: controller.deactivate,
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
          IconButton(
            tooltip: 'Effacer',
            icon: const Icon(Icons.clear),
            onPressed: controller.clearQuery,
          ),
      ],
    );
  }
}
