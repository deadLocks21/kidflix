import 'package:flutter/material.dart';
import 'package:kidflix/ui/focus/kidflix_focusable.widget.dart';

/// Draws the Kidflix focus ring around one part of a focusable, rather
/// than around all of it.
///
/// A catalog card is a poster with a title and a caption underneath, and
/// the text starts flush against the card's edge — a ring around the
/// whole thing ran straight through the first character. Ringing the
/// poster alone is also the truer reading: the poster is the thing being
/// selected, the text is its label.
///
/// Carries no focus node. It reads [KidflixFocusable.isFocused], so it
/// only works below one, and it follows that focusable's state exactly.
class KidflixFocusRing extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const KidflixFocusRing({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final on = KidflixFocusable.isFocused(context);
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: KidflixFocusable.duration,
      curve: KidflixFocusable.curve,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        // Lifts the poster off the black background, so a focused card
        // reads as being in front of its neighbours rather than merely
        // outlined. Cast downwards rather than spread evenly: the row
        // clips, and above the poster there is barely a dozen points of
        // slack once the zoom has taken its share.
        boxShadow: on
            ? const [
                BoxShadow(
                  color: Color(0xB3000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ]
            : const [],
      ),
      // Painted over the poster's edge rather than around it: a border in
      // `decoration` would inset the image by its width and make the card
      // twitch as focus lands.
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: on ? KidflixFocusable.ringColor(scheme) : Colors.transparent,
          width: KidflixFocusable.ringWidth,
        ),
      ),
      child: child,
    );
  }
}
