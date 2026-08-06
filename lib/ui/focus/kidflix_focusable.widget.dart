import 'package:flutter/material.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';

/// Tappable surface that shows a Kidflix focus ring while it holds focus
/// **and** the user is driving with the keyboard (cf. [KeyboardModeScope]).
///
/// Wraps the [InkWell] the cards used to build themselves rather than
/// sitting on top of one: two nested focusables would mean two focus nodes
/// for one visual element, and arrow traversal would stop on both.
///
/// The ring is a foreground decoration and the zoom is an [AnimatedScale],
/// so neither changes the widget's layout size — a focused card must not
/// nudge its neighbours. It does *paint* outside its box though: a host
/// with a clipping viewport (the catalog rows) has to leave
/// `(scale - 1) / 2` of slack around each item or the zoom gets cropped.
class KidflixFocusable extends StatefulWidget {
  final Widget child;

  /// Fired by tap and, when focused, by Enter / Space / a remote's OK —
  /// [ActivateIntent] is wired to [InkWell] by the framework.
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  /// Takes focus on mount. Exactly one per page / modal.
  final bool autofocus;

  /// Supplied by hosts that drive focus themselves — the catalog
  /// coordinator owns one node per (row, column).
  final FocusNode? focusNode;

  final BorderRadius borderRadius;

  /// Zoom applied while focused. Kept modest: the rows only have so much
  /// vertical slack, and the ring already carries most of the signal.
  final double scale;

  const KidflixFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.autofocus = false,
    this.focusNode,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.scale = 1.06,
  });

  /// Extra room a host must reserve around an item of [extent] so the zoom
  /// is not clipped by a surrounding viewport.
  static double slackFor(double extent, {double scale = 1.06}) =>
      extent * (scale - 1) / 2;

  static const Duration _duration = Duration(milliseconds: 140);
  static const double _ringWidth = 3;

  @override
  State<KidflixFocusable> createState() => _KidflixFocusableState();
}

class _KidflixFocusableState extends State<KidflixFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final surface = Material(
      color: Colors.transparent,
      child: InkWell(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onFocusChange: (focused) {
          if (focused == _focused) return;
          setState(() => _focused = focused);
        },
        borderRadius: widget.borderRadius,
        child: widget.child,
      ),
    );
    final mode = KeyboardModeScope.maybeOf(context);
    if (mode == null) return surface;
    return ValueListenableBuilder<bool>(
      valueListenable: mode,
      builder: (context, keyboard, child) =>
          _decorate(context, on: keyboard && _focused, child: child!),
      child: surface,
    );
  }

  Widget _decorate(
    BuildContext context, {
    required bool on,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: on ? widget.scale : 1,
      duration: KidflixFocusable._duration,
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: KidflixFocusable._duration,
        curve: Curves.easeOut,
        // `decoration` would inset the child by the border width and make
        // the card twitch as focus arrives; `foregroundDecoration` paints
        // the ring over the poster edge and leaves layout alone.
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: on
              ? const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: on ? scheme.primary : Colors.transparent,
            width: KidflixFocusable._ringWidth,
          ),
        ),
        child: child,
      ),
    );
  }
}
