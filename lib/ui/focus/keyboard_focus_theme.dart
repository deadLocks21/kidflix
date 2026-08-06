import 'package:flutter/material.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';

/// Gives every Material button and tile a focus state you can actually see,
/// while the user is on the keyboard.
///
/// The design system never styled `focused`, so the framework defaults
/// applied — and they are invisible here. `IconButton.styleFrom` derives its
/// overlay from `foregroundColor`, which [KidflixIconButtonStyles.mediaFlat]
/// sets to white: a focused icon button was drawing white at 10 % opacity on
/// a black app bar. `ListTile` and friends fall back to `ThemeData.focusColor`,
/// no better on this palette.
///
/// Both get fixed here rather than at each call site, because both are
/// theme-level defaults:
///
/// - buttons take a `side`, which resolves to the same primary ring the
///   posters use. `ButtonStyle.side` is merged into the existing style, so a
///   button that already carries a border keeps it in every other state;
/// - everything [InkWell]-based takes a stronger [ThemeData.focusColor].
///   Material has no ring for tiles, so a wash is the honest option there.
///
/// Sits below [KeyboardModeScope] so it can read the mode, and above the
/// router so it reaches every page. It only swaps the theme when the mode
/// actually flips, which is rare — a full-app rebuild on the first arrow key
/// and on the first click that follows it.
class KeyboardFocusTheme extends StatelessWidget {
  final Widget child;

  const KeyboardFocusTheme({super.key, required this.child});

  /// Thinner than the posters' ring: the same 3 dp around a 40 dp icon button
  /// reads as a border, not as a highlight.
  static const double ringWidth = 2;

  @override
  Widget build(BuildContext context) {
    final mode = KeyboardModeScope.maybeOf(context);
    if (mode == null) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: mode,
      builder: (context, keyboard, child) => keyboard
          ? Theme(data: _focusVisibleTheme(Theme.of(context)), child: child!)
          : child!,
      child: child,
    );
  }
}

ThemeData _focusVisibleTheme(ThemeData base) {
  final ring = base.colorScheme.primary;
  return base.copyWith(
    focusColor: ring.withValues(alpha: 0.3),
    iconButtonTheme: IconButtonThemeData(
      style: _withFocusRing(base.iconButtonTheme.style, ring),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _withFocusRing(base.filledButtonTheme.style, ring),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _withFocusRing(base.outlinedButtonTheme.style, ring),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _withFocusRing(base.textButtonTheme.style, ring),
    ),
  );
}

/// Copies [base] with a `side` that is the focus ring while focused and the
/// style's original side otherwise — dropping it would strip the border off
/// every outlined button the moment this theme applies.
ButtonStyle _withFocusRing(ButtonStyle? base, Color color) {
  final original = base?.side;
  return (base ?? const ButtonStyle()).copyWith(
    side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: color, width: KeyboardFocusTheme.ringWidth);
      }
      return original?.resolve(states);
    }),
  );
}
