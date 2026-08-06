import 'package:flutter/material.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';
import 'package:kidflix/ui/focus/kidflix_focusable.widget.dart';

/// Grows whatever it wraps while that thing holds focus and the user is on
/// the keyboard — the poster zoom, applied to a widget we do not build.
///
/// [KidflixFocusable] owns its `InkWell` and can decorate it directly.
/// Material's buttons build their own, and `ButtonStyle` has no notion of
/// scale, so the ring reaches them through the theme
/// ([KeyboardFocusTheme]) while the zoom has to come from a wrapper.
///
/// The focus is observed rather than held: the [Focus] here cannot take
/// focus and is skipped by traversal, it only reports when a *descendant*
/// has it. Wrapping therefore adds nothing to the tab order and leaves the
/// button's own focus node in charge.
///
/// Reserved for compact controls — icon buttons, dialog actions, the
/// actions of a detail modal. A full-width button or list tile would slide
/// several dozen pixels sideways as it grew; those keep the ring alone.
class KidflixFocusZoom extends StatefulWidget {
  final Widget child;
  final double scale;

  const KidflixFocusZoom({
    super.key,
    required this.child,
    this.scale = KidflixFocusable.defaultScale,
  });

  @override
  State<KidflixFocusZoom> createState() => _KidflixFocusZoomState();
}

class _KidflixFocusZoomState extends State<KidflixFocusZoom> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tracked = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused == _focused) return;
        setState(() => _focused = focused);
      },
      child: widget.child,
    );
    final mode = KeyboardModeScope.maybeOf(context);
    if (mode == null) return tracked;
    return ValueListenableBuilder<bool>(
      valueListenable: mode,
      builder: (context, keyboard, child) => AnimatedScale(
        scale: keyboard && _focused ? widget.scale : 1,
        duration: KidflixFocusable.duration,
        curve: KidflixFocusable.curve,
        child: child!,
      ),
      child: tracked,
    );
  }
}
