import 'package:flutter/material.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';

/// Keyboard traversal for the home catalog, driven by (row, column)
/// coordinates instead of by geometry.
///
/// Flutter's default directional traversal picks the focusable nearest to
/// the current one *on screen*. That falls apart on a Netflix-style grid
/// for two reasons:
///
/// - each row scrolls independently, so the poster physically below the
///   focused one is whichever the row underneath happens to be showing —
///   pressing down twice can walk diagonally across the catalog;
/// - both the rows ([SliverList.builder]) and the posters inside them
///   ([ListView.builder]) are built lazily, and the traversal can only
///   reach nodes that already exist. Focus stops dead at the last poster
///   the viewport bothered to build.
///
/// This coordinator fixes both: it keeps a registry of the live nodes, and
/// when a move targets a poster that has not been built it scrolls the row
/// to it first and grabs focus on the next frame. Vertical moves carry the
/// current column over, clamped to the target row's length, so leaving the
/// 8th poster of one row lands on the 8th of the next.
///
/// Anything the registry does not know about — the app bar, an empty row,
/// the edges of the catalog — falls through to the framework's own
/// traversal untouched.
class CatalogFocusScope extends StatefulWidget {
  final Widget child;

  /// `false` while something else owns the keyboard — search mode, which
  /// hides the catalog behind an [ExcludeFocus]. Coming back to `true`
  /// hands focus to the poster the user left, instead of making them press
  /// an arrow twice to re-enter the grid from nowhere.
  final bool enabled;

  const CatalogFocusScope({
    super.key,
    required this.child,
    this.enabled = true,
  });

  static CatalogFocusCoordinator? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_CatalogFocusMarker>()
      ?.coordinator;

  @override
  State<CatalogFocusScope> createState() => _CatalogFocusScopeState();
}

class _CatalogFocusScopeState extends State<CatalogFocusScope> {
  final CatalogFocusCoordinator _coordinator = CatalogFocusCoordinator();

  @override
  void didUpdateWidget(CatalogFocusScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled || !widget.enabled) return;
    // Deferred by a frame: the [ExcludeFocus] above still holds this
    // subtree unfocusable until the rebuild it belongs to has landed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _coordinator._restoreFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _CatalogFocusMarker(
      coordinator: _coordinator,
      child: Actions(
        actions: <Type, Action<Intent>>{
          DirectionalFocusIntent: _CatalogDirectionalFocusAction(this),
        },
        child: widget.child,
      ),
    );
  }
}

class _CatalogFocusMarker extends InheritedWidget {
  final CatalogFocusCoordinator coordinator;

  const _CatalogFocusMarker({required this.coordinator, required super.child});

  @override
  bool updateShouldNotify(_CatalogFocusMarker oldWidget) =>
      coordinator != oldWidget.coordinator;
}

class _CatalogDirectionalFocusAction extends DirectionalFocusAction {
  final _CatalogFocusScopeState _scope;

  _CatalogDirectionalFocusAction(this._scope);

  @override
  void invoke(DirectionalFocusIntent intent) {
    // This action shadows the one [KeyboardModeScope] installs at the
    // root, so the "first press only reveals the ring" rule has to be
    // honoured here too.
    if (KeyboardModeScope.revealOnly(_scope.context)) return;
    // While search mode owns the screen the grid is hidden behind an
    // [ExcludeFocus] ; letting the coordinator answer would drag focus
    // into posters the user cannot see.
    if (_scope.widget.enabled && _scope._coordinator._move(intent.direction)) {
      return;
    }
    super.invoke(intent);
  }
}

/// Live registry of the catalog's focus nodes, plus the movement rules.
class CatalogFocusCoordinator {
  final Map<int, _RowSlot> _rows = <int, _RowSlot>{};
  final Map<FocusNode, ({int row, int column})> _slots =
      <FocusNode, ({int row, int column})>{};

  /// Guards the one-shot initial focus. Rows recycle their cards as they
  /// scroll, and an `autofocus` that stayed armed would snatch focus back
  /// every time poster (0, 0) was rebuilt.
  bool _initialFocusPlaced = false;

  /// Where the keyboard left off, for [_restoreFocus].
  FocusNode? _lastFocused;

  void _attachRow(int index, _RowSlot slot) => _rows[index] = slot;

  void _detachRow(int index, _RowSlot slot) {
    // A row that has already been replaced by another at the same index
    // must not be able to unregister its successor.
    if (identical(_rows[index], slot)) _rows.remove(index);
  }

  void _attachItem(int row, int column, FocusNode node) {
    _rows[row]?.nodes[column] = node;
    _slots[node] = (row: row, column: column);
  }

  void _detachItem(FocusNode node) {
    final slot = _slots.remove(node);
    if (slot == null) return;
    final row = _rows[slot.row];
    if (identical(row?.nodes[slot.column], node)) {
      row!.nodes.remove(slot.column);
    }
  }

  /// Whether the poster at ([row], [column]) should take focus on mount.
  /// True at most once per coordinator, for the very first poster.
  bool _claimInitialFocus(int row, int column) {
    if (_initialFocusPlaced || row != 0 || column != 0) return false;
    _initialFocusPlaced = true;
    return true;
  }

  /// Moves focus one step in [direction]. Returns `false` when the move is
  /// none of this coordinator's business, so the caller can fall back to
  /// the framework's traversal.
  bool _move(TraversalDirection direction) {
    final origin = _slots[FocusManager.instance.primaryFocus];
    if (origin == null) {
      // Focus is outside the grid — in practice the app bar, the only
      // thing sitting above it. Coming back down has to be answered here
      // rather than left to geometry: the framework looks for whatever is
      // directly below the button, finds nothing under a first row that
      // stops short of the screen edge, and settles for the nearest
      // poster in the row *below* it.
      return direction == TraversalDirection.down && _restoreFocus();
    }
    return switch (direction) {
      TraversalDirection.left => _step(origin, -1),
      TraversalDirection.right => _step(origin, 1),
      // Vertical moves carry the column over, clamped: a short row still
      // catches a move coming from deep inside a long one. Off the top or
      // the bottom of the catalog they fall through, which is what lets
      // the first row reach the app bar.
      TraversalDirection.up => _focusAt(
        origin.row - 1,
        origin.column,
        forward: false,
        clamp: true,
      ),
      TraversalDirection.down => _focusAt(
        origin.row + 1,
        origin.column,
        forward: true,
        clamp: true,
      ),
    };
  }

  /// Moves [delta] posters along the row, and stops at its ends.
  ///
  /// The key is swallowed there rather than handed back to the framework.
  /// A catalog row spans the full width, so there is nothing legitimate to
  /// reach sideways — but the default traversal does not know that, and
  /// would gladly jump to a poster of the row *above or below* that
  /// happens to sit further right on screen. Leaving the last poster of a
  /// short row then looked like the selection carrying on into another
  /// row.
  bool _step(({int row, int column}) origin, int delta) {
    final slot = _rows[origin.row];
    if (slot == null || slot.itemCount == 0) return false;
    final target = (origin.column + delta).clamp(0, slot.itemCount - 1);
    if (target == origin.column) return true;
    return _focusAt(origin.row, target, forward: delta > 0);
  }

  bool _focusAt(
    int row,
    int column, {
    required bool forward,
    bool clamp = false,
  }) {
    final slot = _rows[row];
    if (slot == null || slot.itemCount == 0) return false;
    final target = clamp ? column.clamp(0, slot.itemCount - 1) : column;
    if (target < 0 || target >= slot.itemCount) return false;

    final node = slot.nodes[target];
    if (node != null) {
      _focus(node, forward: forward);
      return true;
    }
    // The poster exists in the row's data but not in the widget tree.
    // Scroll it into view and take focus once the list has laid it out.
    slot.revealColumn(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final built = _rows[row]?.nodes[target];
      if (built != null) _focus(built, forward: forward);
    });
    return true;
  }

  /// Puts focus back on the poster the keyboard last used, or on the first
  /// one still built if that poster has since been recycled away.
  ///
  /// Serves both ways back into the grid — returning from search, and
  /// coming down from the app bar — so the two behave alike: you land
  /// where you left off, which for someone who went straight up from the
  /// very first poster is that same first poster.
  ///
  /// Returns `false` when the grid holds nothing to focus yet (skeleton,
  /// empty or failed catalog), leaving the key to the caller.
  bool _restoreFocus() {
    final remembered = _lastFocused;
    if (remembered != null && remembered.canRequestFocus) {
      _focus(remembered, forward: true);
      return true;
    }
    final rows = _rows.keys.toList()..sort();
    for (final row in rows) {
      final columns = _rows[row]!.nodes.keys.toList()..sort();
      if (columns.isEmpty) continue;
      _focus(_rows[row]!.nodes[columns.first]!, forward: false);
      return true;
    }
    return false;
  }

  void _focus(FocusNode node, {required bool forward}) {
    _lastFocused = node;
    node.requestFocus();
    final context = node.context;
    if (context == null) return;
    // `requestFocus` alone does not scroll — only the traversal policy
    // does that, and we just bypassed it. One call walks every enclosing
    // viewport, so this scrolls the row *and* the page.
    Scrollable.ensureVisible(
      context,
      alignment: forward ? 1 : 0,
      alignmentPolicy: forward
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }
}

/// One registered catalog row: how many posters it holds, how to scroll it
/// and which of its posters currently exist.
class _RowSlot {
  final ScrollController controller;
  final int itemCount;

  /// Distance from one poster's leading edge to the next.
  final double stride;

  /// Leading padding of the row's [ListView].
  final double leadingInset;

  /// Width of a single poster.
  final double itemExtent;

  final Map<int, FocusNode> nodes = <int, FocusNode>{};

  _RowSlot({
    required this.controller,
    required this.itemCount,
    required this.stride,
    required this.leadingInset,
    required this.itemExtent,
  });

  /// Centres poster [column] in the row, so the list builds it.
  void revealColumn(int column) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final offset =
        leadingInset +
        column * stride -
        position.viewportDimension / 2 +
        itemExtent / 2;
    controller.jumpTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }
}

/// Registers a catalog row with the ambient [CatalogFocusScope] and hands
/// its posters a [ScrollController] to attach to.
class CatalogFocusRow extends StatefulWidget {
  final int index;
  final int itemCount;
  final double stride;
  final double leadingInset;
  final double itemExtent;
  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  const CatalogFocusRow({
    super.key,
    required this.index,
    required this.itemCount,
    required this.stride,
    required this.leadingInset,
    required this.itemExtent,
    required this.builder,
  });

  @override
  State<CatalogFocusRow> createState() => _CatalogFocusRowState();
}

class _CatalogFocusRowState extends State<CatalogFocusRow> {
  final ScrollController _controller = ScrollController();
  CatalogFocusCoordinator? _coordinator;
  _RowSlot? _slot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register(CatalogFocusScope.maybeOf(context));
  }

  @override
  void didUpdateWidget(CatalogFocusRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The sliver recycles row elements, so the same state can end up
    // serving a different row index — re-register under the new one.
    if (oldWidget.index != widget.index ||
        oldWidget.itemCount != widget.itemCount) {
      _register(_coordinator, force: true);
    }
  }

  void _register(CatalogFocusCoordinator? coordinator, {bool force = false}) {
    if (!force && identical(coordinator, _coordinator) && _slot != null) return;
    _unregister();
    _coordinator = coordinator;
    if (coordinator == null) return;
    final slot = _RowSlot(
      controller: _controller,
      itemCount: widget.itemCount,
      stride: widget.stride,
      leadingInset: widget.leadingInset,
      itemExtent: widget.itemExtent,
    );
    _slot = slot;
    coordinator._attachRow(widget.index, slot);
  }

  void _unregister() {
    final slot = _slot;
    if (slot == null) return;
    for (final node in slot.nodes.values.toList()) {
      _coordinator?._detachItem(node);
    }
    _coordinator?._detachRow(_indexOf(slot), slot);
    _slot = null;
  }

  /// The index the outgoing [slot] was filed under, which is the widget's
  /// previous index during a recycle.
  int _indexOf(_RowSlot slot) {
    final rows = _coordinator?._rows;
    if (rows == null) return widget.index;
    for (final entry in rows.entries) {
      if (identical(entry.value, slot)) return entry.key;
    }
    return widget.index;
  }

  @override
  void dispose() {
    _unregister();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

/// Registers one poster at ([row], [column]) and hands its focus node to
/// the card. [autofocus] is granted to the very first poster only.
class CatalogFocusItem extends StatefulWidget {
  final int row;
  final int column;
  final Widget Function(BuildContext context, FocusNode node, bool autofocus)
  builder;

  const CatalogFocusItem({
    super.key,
    required this.row,
    required this.column,
    required this.builder,
  });

  @override
  State<CatalogFocusItem> createState() => _CatalogFocusItemState();
}

class _CatalogFocusItemState extends State<CatalogFocusItem> {
  late final FocusNode _node = FocusNode(
    debugLabel: 'catalog(${widget.row}, ${widget.column})',
  );
  CatalogFocusCoordinator? _coordinator;
  bool _autofocus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinator = CatalogFocusScope.maybeOf(context);
    if (identical(coordinator, _coordinator)) return;
    _coordinator?._detachItem(_node);
    _coordinator = coordinator;
    coordinator?._attachItem(widget.row, widget.column, _node);
    _autofocus =
        _autofocus ||
        (coordinator?._claimInitialFocus(widget.row, widget.column) ?? false);
  }

  @override
  void didUpdateWidget(CatalogFocusItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row == widget.row && oldWidget.column == widget.column) {
      return;
    }
    _coordinator?._detachItem(_node);
    _coordinator?._attachItem(widget.row, widget.column, _node);
  }

  @override
  void dispose() {
    _coordinator?._detachItem(_node);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _node, _autofocus);
}
