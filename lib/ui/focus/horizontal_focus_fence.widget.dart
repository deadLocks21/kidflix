import 'package:flutter/material.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';

/// Keeps left/right traversal inside each [HorizontalFocusFence] below it.
///
/// Directional traversal is pure geometry: to move right it keeps every
/// focusable whose centre lies beyond the current node's right edge, and
/// takes the nearest. In a row of buttons at the edge of a modal, the
/// nearest such thing is whatever else happens to stick out further right
/// — the sheet's close button, for instance, which may well be scrolled
/// off the top of the screen by then. The focus does not disappear, but it
/// may as well have.
///
/// So a sideways move that would leave the fence it started in is refused
/// and the focus stays put. Vertical moves are left alone: they are the
/// way out.
///
/// The traversal policy lives **here**, once, rather than in each fence.
/// A policy remembers the direction of the last move so that reversing it
/// walks back along the same path, and that history is per policy
/// instance. One policy per row fragments it into a dozen stale copies,
/// each recording only "I once left this row going down" — after which
/// pressing up on that row pops the entry, re-focuses the node already
/// focused, and eats the keystroke. Which looks exactly like a list that
/// sometimes needs two presses to move one line.
class HorizontalFocusFenceScope extends StatefulWidget {
  final Widget child;

  const HorizontalFocusFenceScope({super.key, required this.child});

  static _FenceRegistry? _maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_FenceRegistryMarker>()
      ?.registry;

  @override
  State<HorizontalFocusFenceScope> createState() =>
      _HorizontalFocusFenceScopeState();
}

class _HorizontalFocusFenceScopeState extends State<HorizontalFocusFenceScope> {
  final _FenceRegistry _registry = _FenceRegistry();

  bool _sideways = false;

  late final FocusTraversalPolicy _policy = ReadingOrderTraversalPolicy(
    requestFocusCallback: _requestFocus,
  );

  void _requestFocus(
    FocusNode node, {
    ScrollPositionAlignmentPolicy? alignmentPolicy,
    double? alignment,
    Duration? duration,
    Curve? curve,
  }) {
    if (_sideways) {
      final from = _registry.fenceOf(FocusManager.instance.primaryFocus);
      if (from != null && _registry.fenceOf(node) != from) {
        // The policy logs the move in its direction history before asking
        // where to land. Left behind, that entry makes the next press the
        // other way spend itself undoing a move that never happened.
        final scope = FocusManager.instance.primaryFocus?.nearestScope;
        if (scope != null) _policy.invalidateScopeData(scope);
        return;
      }
    }
    FocusTraversalPolicy.defaultTraversalRequestFocusCallback(
      node,
      alignmentPolicy: alignmentPolicy,
      alignment: alignment,
      duration: duration,
      curve: curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FenceRegistryMarker(
      registry: _registry,
      child: FocusTraversalGroup(
        policy: _policy,
        child: Actions(
          actions: <Type, Action<Intent>>{
            DirectionalFocusIntent: _FenceDirectionalFocusAction(this),
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// The fence boundaries currently mounted below a scope.
class _FenceRegistry {
  final Set<FocusNode> _fences = <FocusNode>{};

  void add(FocusNode fence) => _fences.add(fence);

  void remove(FocusNode fence) => _fences.remove(fence);

  /// The innermost fence containing [node], or `null` when it sits
  /// outside every fence — the modal's own buttons, say.
  FocusNode? fenceOf(FocusNode? node) {
    if (node == null || _fences.isEmpty) return null;
    if (_fences.contains(node)) return node;
    for (final ancestor in node.ancestors) {
      if (_fences.contains(ancestor)) return ancestor;
    }
    return null;
  }
}

class _FenceRegistryMarker extends InheritedWidget {
  final _FenceRegistry registry;

  const _FenceRegistryMarker({required this.registry, required super.child});

  @override
  bool updateShouldNotify(_FenceRegistryMarker oldWidget) =>
      registry != oldWidget.registry;
}

class _FenceDirectionalFocusAction extends DirectionalFocusAction {
  final _HorizontalFocusFenceScopeState _scope;

  _FenceDirectionalFocusAction(this._scope);

  @override
  void invoke(DirectionalFocusIntent intent) {
    // This shadows the action [KeyboardModeScope] installs at the root, so
    // the "first press only reveals the ring" rule applies here too.
    if (KeyboardModeScope.revealOnly(_scope.context)) return;
    final sideways =
        intent.direction == TraversalDirection.left ||
        intent.direction == TraversalDirection.right;
    if (!sideways) {
      super.invoke(intent);
      return;
    }
    _scope._sideways = true;
    try {
      super.invoke(intent);
    } finally {
      _scope._sideways = false;
    }
  }
}

/// Marks one horizontal group — a row of buttons, typically. Carries no
/// behaviour of its own: the enclosing [HorizontalFocusFenceScope] reads
/// these boundaries when it decides whether a sideways move may land.
class HorizontalFocusFence extends StatefulWidget {
  final Widget child;

  const HorizontalFocusFence({super.key, required this.child});

  @override
  State<HorizontalFocusFence> createState() => _HorizontalFocusFenceState();
}

class _HorizontalFocusFenceState extends State<HorizontalFocusFence> {
  /// Holds no focus of its own and is skipped by traversal; it exists so
  /// the registry has something to test node ancestry against.
  final FocusNode _fence = FocusNode(
    canRequestFocus: false,
    skipTraversal: true,
    debugLabel: 'horizontal-focus-fence',
  );

  _FenceRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = HorizontalFocusFenceScope._maybeOf(context);
    if (identical(registry, _registry)) return;
    _registry?.remove(_fence);
    _registry = registry;
    registry?.add(_fence);
  }

  @override
  void dispose() {
    _registry?.remove(_fence);
    _fence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _fence,
    canRequestFocus: false,
    skipTraversal: true,
    child: widget.child,
  );
}
