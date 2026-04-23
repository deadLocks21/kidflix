import 'package:flutter/material.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.red100,
    required this.red200,
    required this.red300,
    required this.blue100,
    required this.blue200,
    required this.blue300,
    required this.green,
    required this.grey10,
    required this.grey20,
    required this.grey25,
    required this.grey50,
    required this.grey100,
    required this.grey150,
    required this.grey200,
    required this.grey250,
    required this.grey300T40,
    required this.grey300T70,
    required this.grey350,
    required this.grey400,
    required this.grey450,
    required this.grey500,
    required this.grey550,
    required this.grey600,
    required this.grey600T60,
    required this.grey650,
    required this.grey700,
    required this.grey750,
    required this.grey800,
    required this.grey850,
    required this.grey900,
    required this.transparentWhite15,
    required this.transparentWhite20,
    required this.transparentWhite30,
    required this.transparentWhite35,
    required this.transparentWhite50,
    required this.transparentWhite70,
    required this.transparentBlack30,
    required this.transparentBlack60,
    required this.transparentBlack90,
  });

  const AppColors.dark()
    : this(
        red100: KidflixPalette.red100,
        red200: KidflixPalette.red200,
        red300: KidflixPalette.red300,
        blue100: KidflixPalette.blue100,
        blue200: KidflixPalette.blue200,
        blue300: KidflixPalette.blue300,
        green: KidflixPalette.green,
        grey10: KidflixPalette.grey10,
        grey20: KidflixPalette.grey20,
        grey25: KidflixPalette.grey25,
        grey50: KidflixPalette.grey50,
        grey100: KidflixPalette.grey100,
        grey150: KidflixPalette.grey150,
        grey200: KidflixPalette.grey200,
        grey250: KidflixPalette.grey250,
        grey300T40: KidflixPalette.grey300T40,
        grey300T70: KidflixPalette.grey300T70,
        grey350: KidflixPalette.grey350,
        grey400: KidflixPalette.grey400,
        grey450: KidflixPalette.grey450,
        grey500: KidflixPalette.grey500,
        grey550: KidflixPalette.grey550,
        grey600: KidflixPalette.grey600,
        grey600T60: KidflixPalette.grey600T60,
        grey650: KidflixPalette.grey650,
        grey700: KidflixPalette.grey700,
        grey750: KidflixPalette.grey750,
        grey800: KidflixPalette.grey800,
        grey850: KidflixPalette.grey850,
        grey900: KidflixPalette.grey900,
        transparentWhite15: KidflixPalette.transparentWhite15,
        transparentWhite20: KidflixPalette.transparentWhite20,
        transparentWhite30: KidflixPalette.transparentWhite30,
        transparentWhite35: KidflixPalette.transparentWhite35,
        transparentWhite50: KidflixPalette.transparentWhite50,
        transparentWhite70: KidflixPalette.transparentWhite70,
        transparentBlack30: KidflixPalette.transparentBlack30,
        transparentBlack60: KidflixPalette.transparentBlack60,
        transparentBlack90: KidflixPalette.transparentBlack90,
      );

  final Color red100;
  final Color red200;
  final Color red300;
  final Color blue100;
  final Color blue200;
  final Color blue300;
  final Color green;
  final Color grey10;
  final Color grey20;
  final Color grey25;
  final Color grey50;
  final Color grey100;
  final Color grey150;
  final Color grey200;
  final Color grey250;
  final Color grey300T40;
  final Color grey300T70;
  final Color grey350;
  final Color grey400;
  final Color grey450;
  final Color grey500;
  final Color grey550;
  final Color grey600;
  final Color grey600T60;
  final Color grey650;
  final Color grey700;
  final Color grey750;
  final Color grey800;
  final Color grey850;
  final Color grey900;
  final Color transparentWhite15;
  final Color transparentWhite20;
  final Color transparentWhite30;
  final Color transparentWhite35;
  final Color transparentWhite50;
  final Color transparentWhite70;
  final Color transparentBlack30;
  final Color transparentBlack60;
  final Color transparentBlack90;

  @override
  AppColors copyWith({
    Color? red100,
    Color? red200,
    Color? red300,
    Color? blue100,
    Color? blue200,
    Color? blue300,
    Color? green,
    Color? grey10,
    Color? grey20,
    Color? grey25,
    Color? grey50,
    Color? grey100,
    Color? grey150,
    Color? grey200,
    Color? grey250,
    Color? grey300T40,
    Color? grey300T70,
    Color? grey350,
    Color? grey400,
    Color? grey450,
    Color? grey500,
    Color? grey550,
    Color? grey600,
    Color? grey600T60,
    Color? grey650,
    Color? grey700,
    Color? grey750,
    Color? grey800,
    Color? grey850,
    Color? grey900,
    Color? transparentWhite15,
    Color? transparentWhite20,
    Color? transparentWhite30,
    Color? transparentWhite35,
    Color? transparentWhite50,
    Color? transparentWhite70,
    Color? transparentBlack30,
    Color? transparentBlack60,
    Color? transparentBlack90,
  }) {
    return AppColors(
      red100: red100 ?? this.red100,
      red200: red200 ?? this.red200,
      red300: red300 ?? this.red300,
      blue100: blue100 ?? this.blue100,
      blue200: blue200 ?? this.blue200,
      blue300: blue300 ?? this.blue300,
      green: green ?? this.green,
      grey10: grey10 ?? this.grey10,
      grey20: grey20 ?? this.grey20,
      grey25: grey25 ?? this.grey25,
      grey50: grey50 ?? this.grey50,
      grey100: grey100 ?? this.grey100,
      grey150: grey150 ?? this.grey150,
      grey200: grey200 ?? this.grey200,
      grey250: grey250 ?? this.grey250,
      grey300T40: grey300T40 ?? this.grey300T40,
      grey300T70: grey300T70 ?? this.grey300T70,
      grey350: grey350 ?? this.grey350,
      grey400: grey400 ?? this.grey400,
      grey450: grey450 ?? this.grey450,
      grey500: grey500 ?? this.grey500,
      grey550: grey550 ?? this.grey550,
      grey600: grey600 ?? this.grey600,
      grey600T60: grey600T60 ?? this.grey600T60,
      grey650: grey650 ?? this.grey650,
      grey700: grey700 ?? this.grey700,
      grey750: grey750 ?? this.grey750,
      grey800: grey800 ?? this.grey800,
      grey850: grey850 ?? this.grey850,
      grey900: grey900 ?? this.grey900,
      transparentWhite15: transparentWhite15 ?? this.transparentWhite15,
      transparentWhite20: transparentWhite20 ?? this.transparentWhite20,
      transparentWhite30: transparentWhite30 ?? this.transparentWhite30,
      transparentWhite35: transparentWhite35 ?? this.transparentWhite35,
      transparentWhite50: transparentWhite50 ?? this.transparentWhite50,
      transparentWhite70: transparentWhite70 ?? this.transparentWhite70,
      transparentBlack30: transparentBlack30 ?? this.transparentBlack30,
      transparentBlack60: transparentBlack60 ?? this.transparentBlack60,
      transparentBlack90: transparentBlack90 ?? this.transparentBlack90,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      red100: Color.lerp(red100, other.red100, t) ?? red100,
      red200: Color.lerp(red200, other.red200, t) ?? red200,
      red300: Color.lerp(red300, other.red300, t) ?? red300,
      blue100: Color.lerp(blue100, other.blue100, t) ?? blue100,
      blue200: Color.lerp(blue200, other.blue200, t) ?? blue200,
      blue300: Color.lerp(blue300, other.blue300, t) ?? blue300,
      green: Color.lerp(green, other.green, t) ?? green,
      grey10: Color.lerp(grey10, other.grey10, t) ?? grey10,
      grey20: Color.lerp(grey20, other.grey20, t) ?? grey20,
      grey25: Color.lerp(grey25, other.grey25, t) ?? grey25,
      grey50: Color.lerp(grey50, other.grey50, t) ?? grey50,
      grey100: Color.lerp(grey100, other.grey100, t) ?? grey100,
      grey150: Color.lerp(grey150, other.grey150, t) ?? grey150,
      grey200: Color.lerp(grey200, other.grey200, t) ?? grey200,
      grey250: Color.lerp(grey250, other.grey250, t) ?? grey250,
      grey300T40: Color.lerp(grey300T40, other.grey300T40, t) ?? grey300T40,
      grey300T70: Color.lerp(grey300T70, other.grey300T70, t) ?? grey300T70,
      grey350: Color.lerp(grey350, other.grey350, t) ?? grey350,
      grey400: Color.lerp(grey400, other.grey400, t) ?? grey400,
      grey450: Color.lerp(grey450, other.grey450, t) ?? grey450,
      grey500: Color.lerp(grey500, other.grey500, t) ?? grey500,
      grey550: Color.lerp(grey550, other.grey550, t) ?? grey550,
      grey600: Color.lerp(grey600, other.grey600, t) ?? grey600,
      grey600T60: Color.lerp(grey600T60, other.grey600T60, t) ?? grey600T60,
      grey650: Color.lerp(grey650, other.grey650, t) ?? grey650,
      grey700: Color.lerp(grey700, other.grey700, t) ?? grey700,
      grey750: Color.lerp(grey750, other.grey750, t) ?? grey750,
      grey800: Color.lerp(grey800, other.grey800, t) ?? grey800,
      grey850: Color.lerp(grey850, other.grey850, t) ?? grey850,
      grey900: Color.lerp(grey900, other.grey900, t) ?? grey900,
      transparentWhite15:
          Color.lerp(transparentWhite15, other.transparentWhite15, t) ??
          transparentWhite15,
      transparentWhite20:
          Color.lerp(transparentWhite20, other.transparentWhite20, t) ??
          transparentWhite20,
      transparentWhite30:
          Color.lerp(transparentWhite30, other.transparentWhite30, t) ??
          transparentWhite30,
      transparentWhite35:
          Color.lerp(transparentWhite35, other.transparentWhite35, t) ??
          transparentWhite35,
      transparentWhite50:
          Color.lerp(transparentWhite50, other.transparentWhite50, t) ??
          transparentWhite50,
      transparentWhite70:
          Color.lerp(transparentWhite70, other.transparentWhite70, t) ??
          transparentWhite70,
      transparentBlack30:
          Color.lerp(transparentBlack30, other.transparentBlack30, t) ??
          transparentBlack30,
      transparentBlack60:
          Color.lerp(transparentBlack60, other.transparentBlack60, t) ??
          transparentBlack60,
      transparentBlack90:
          Color.lerp(transparentBlack90, other.transparentBlack90, t) ??
          transparentBlack90,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
