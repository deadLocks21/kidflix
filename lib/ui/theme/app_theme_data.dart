import 'package:flutter/material.dart';
import 'package:kidflix/ui/theme/app_colors.dart';
import 'package:kidflix/ui/theme/button_styles.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

abstract final class AppThemeData {
  const AppThemeData._();

  static ThemeData buildDarkTheme() {
    const colorScheme = ColorScheme.dark(
      primary: KidflixPalette.red,
      onPrimary: KidflixPalette.white,
      secondary: KidflixPalette.blue100,
      onSecondary: KidflixPalette.white,
      tertiary: KidflixPalette.green,
      onTertiary: KidflixPalette.black,
      error: KidflixPalette.red200,
      onError: KidflixPalette.white,
      surface: KidflixPalette.black,
      onSurface: KidflixPalette.white,
      onSurfaceVariant: KidflixPalette.grey100,
      outline: KidflixPalette.grey400,
      outlineVariant: KidflixPalette.grey600,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      extensions: const <ThemeExtension<dynamic>>[AppColors.dark()],
      filledButtonTheme: FilledButtonThemeData(
        style: KidflixButtonStyles.primaryLarge,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: KidflixButtonStyles.outlinedLarge,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: KidflixIconButtonStyles.mediaFlat,
      ),
    );
  }
}
