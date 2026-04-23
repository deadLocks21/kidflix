import 'package:flutter/material.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Kidflix Action Button styles.
///
/// Theme-first design system: Large variants are registered as defaults in
/// `AppThemeData.buildDarkTheme()` (via `filledButtonTheme`, `outlinedButtonTheme`).
/// Non-default variants apply via `style:` at the call site, e.g.
/// `FilledButton(style: KidflixButtonStyles.primarySmall, ...)`.
///
/// Filled variants rely on Material 3 automatic overlays for Hover / Focus /
/// Pressed. Outlined variants use an explicit `overlayColor` with a stronger
/// opacity (transparentWhite15/20) because M3's default 8% overlay is barely
/// visible on a transparent background.
abstract final class KidflixButtonStyles {
  const KidflixButtonStyles._();

  static final WidgetStateProperty<Color?> _outlinedOverlay =
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return KidflixPalette.transparentWhite20;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return KidflixPalette.transparentWhite15;
        }
        return null;
      });

  /// Primary CTA, Large (40 px). Default for `FilledButton` via `filledButtonTheme`.
  static final ButtonStyle primaryLarge = FilledButton.styleFrom(
    backgroundColor: KidflixPalette.red,
    foregroundColor: KidflixPalette.white,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  );

  /// Primary CTA, Small (32 px). Apply via `style:`.
  static final ButtonStyle primarySmall = FilledButton.styleFrom(
    backgroundColor: KidflixPalette.red,
    foregroundColor: KidflixPalette.white,
    minimumSize: const Size(0, 32),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  );

  /// Secondary CTA (grey fill), Large (40 px). Apply via `style:`.
  static final ButtonStyle secondaryLarge = FilledButton.styleFrom(
    backgroundColor: KidflixPalette.grey400,
    foregroundColor: KidflixPalette.white,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  );

  /// Secondary CTA (grey fill), Small (32 px). Apply via `style:`.
  static final ButtonStyle secondarySmall = FilledButton.styleFrom(
    backgroundColor: KidflixPalette.grey400,
    foregroundColor: KidflixPalette.white,
    minimumSize: const Size(0, 32),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  );

  /// Outlined CTA, Large (40 px). Default for `OutlinedButton` via `outlinedButtonTheme`.
  static final ButtonStyle outlinedLarge = OutlinedButton.styleFrom(
    foregroundColor: KidflixPalette.white,
    side: const BorderSide(color: KidflixPalette.transparentWhite70),
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  ).copyWith(overlayColor: _outlinedOverlay);

  /// Outlined CTA, Small (32 px). Apply via `style:`.
  static final ButtonStyle outlinedSmall = OutlinedButton.styleFrom(
    foregroundColor: KidflixPalette.white,
    side: const BorderSide(color: KidflixPalette.transparentWhite70),
    minimumSize: const Size(0, 32),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  ).copyWith(overlayColor: _outlinedOverlay);

  /// White filled CTA for on-dark contexts (e.g. "Play"). Large (40 px). Apply via `style:`.
  static final ButtonStyle onDarkFilled = FilledButton.styleFrom(
    backgroundColor: KidflixPalette.white,
    foregroundColor: KidflixPalette.black,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  );

  /// Outlined CTA for on-dark contexts (e.g. "More Info"). Large (40 px). Apply via `style:`.
  static final ButtonStyle onDarkOutlined = OutlinedButton.styleFrom(
    foregroundColor: KidflixPalette.white,
    side: const BorderSide(color: KidflixPalette.transparentWhite70),
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  ).copyWith(overlayColor: _outlinedOverlay);
}

/// Kidflix Icon Button styles.
///
/// Theme-first: `mediaFlat` is the default for `IconButton` via `iconButtonTheme`.
/// `circleOutlined` applies via `style:` on `IconButton.outlined(...)`.
abstract final class KidflixIconButtonStyles {
  const KidflixIconButtonStyles._();

  /// Flat icon button (transparent bg, white foreground). Default for `IconButton`
  /// via `iconButtonTheme`. Used for Video Player controls.
  static final ButtonStyle mediaFlat = IconButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: KidflixPalette.white,
  );

  /// Round outlined icon button (40×40, border `transparentWhite70`). Apply via
  /// `IconButton.outlined(style: KidflixIconButtonStyles.circleOutlined, ...)`.
  /// Used for Hero Banner Preview controls.
  static final ButtonStyle circleOutlined = IconButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: KidflixPalette.white,
    side: const BorderSide(color: KidflixPalette.transparentWhite70),
    shape: const CircleBorder(),
    fixedSize: const Size(40, 40),
    iconSize: 20,
  );
}
