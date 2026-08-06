import 'package:flutter/material.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';

/// Keeps left/right traversal inside its subtree.
///
/// Directional traversal is pure geometry: to move right it keeps every
/// focusable whose centre lies beyond the current node's right edge, and
/// takes the nearest. In a row of buttons at the edge of a modal, the
/// nearest such thing is whatever else happens to stick out further right
/// — the sheet's close button, for instance, which may well be scrolled
/// off the top of the screen by then. The focus does not disappear, but it
/// may as well have.
///
/// So a sideways move that would land outside is refused and the focus
/// stays put, exactly like the ends of a catalog row: sideways walks the
/// row, up and down leave it.
///
/// Vertical moves are left alone — they are the way out.
class HorizontalFocusFence extends StatefulWidget {
  final Widget child;

  const HorizontalFocusFence({super.key, required this.child});

  @override
  State<HorizontalFocusFence> createState() => _HorizontalFocusFenceState();
}

class _HorizontalFocusFenceState extends State<HorizontalFocusFence> {
  /// Marks the boundary. It holds no focus of its own and is skipped by
  /// traversal; it exists so [_isInside] has something to test against.
  final FocusNode _fence = FocusNode(
    canRequestFocus: false,
    skipTraversal: true,
    debugLabel: 'horizontal-focus-fence',
  );

  bool _sideways = false;

  late final FocusTraversalPolicy _policy = ReadingOrderTraversalPolicy(
    requestFocusCallback: _requestFocus,
  );

  @override
  void dispose() {
    _fence.dispose();
    super.dispose();
  }

  bool _isInside(FocusNode node) =>
      node == _fence || node.ancestors.contains(_fence);

  void _requestFocus(
    FocusNode node, {
    ScrollPositionAlignmentPolicy? alignmentPolicy,
    double? alignment,
    Duration? duration,
    Curve? curve,
  }) {
    if (_sideways && !_isInside(node)) {
      // The policy logs the move in its direction history before asking
      // where to land. Left behind, that entry makes the next press the
      // other way spend itself undoing a move that never happened.
      final scope = FocusManager.instance.primaryFocus?.nearestScope;
      if (scope != null) _policy.invalidateScopeData(scope);
      return;
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
    return Focus(
      focusNode: _fence,
      canRequestFocus: false,
      skipTraversal: true,
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

class _FenceDirectionalFocusAction extends DirectionalFocusAction {
  final _HorizontalFocusFenceState _fence;

  _FenceDirectionalFocusAction(this._fence);

  @override
  void invoke(DirectionalFocusIntent intent) {
    // This shadows the action [KeyboardModeScope] installs at the root, so
    // the "first press only reveals the ring" rule applies here too.
    if (KeyboardModeScope.revealOnly(_fence.context)) return;
    final sideways =
        intent.direction == TraversalDirection.left ||
        intent.direction == TraversalDirection.right;
    if (!sideways) {
      super.invoke(intent);
      return;
    }
    _fence._sideways = true;
    try {
      super.invoke(intent);
    } finally {
      _fence._sideways = false;
    }
  }
}
