import 'package:flutter/material.dart';

abstract final class KidflixPalette {
  const KidflixPalette._();

  // Primary
  static const Color black = Color(0xFF000000);
  static const Color red = Color(0xFFE50914);
  static const Color white = Color(0xFFFFFFFF);

  // Secondary — Red
  static const Color red100 = Color(0xFFEB3942);
  static const Color red200 = Color(0xFFC11119);
  static const Color red300 = Color(0xFFF50723);

  // Secondary — Blue
  static const Color blue100 = Color(0xFF0071EB);
  static const Color blue200 = Color(0xFF448EF4);
  static const Color blue300 = Color(0xFF54B9C5);

  // Secondary — Green
  static const Color green = Color(0xFF46D369);

  // Neutral — Grey (opaque)
  static const Color grey10 = Color(0xFFE5E5E5);
  static const Color grey20 = Color(0xFFDCDCDC);
  static const Color grey25 = Color(0xFFD2D2D2);
  static const Color grey50 = Color(0xFFBCBCBC);
  static const Color grey100 = Color(0xFFB3B3B3);
  static const Color grey150 = Color(0xFF979797);
  static const Color grey200 = Color(0xFF808080);
  static const Color grey250 = Color(0xFF777777);
  static const Color grey350 = Color(0xFF545454);
  static const Color grey400 = Color(0xFF414141);
  static const Color grey450 = Color(0xFF404040);
  static const Color grey500 = Color(0xFF3A3A3A);
  static const Color grey550 = Color(0xFF363636);
  static const Color grey600 = Color(0xFF333333);
  static const Color grey650 = Color(0xFF2F2F2F);
  static const Color grey700 = Color(0xFF2A2A2A);
  static const Color grey750 = Color(0xFF262626);
  static const Color grey800 = Color(0xFF232323);
  static const Color grey850 = Color(0xFF181818);
  static const Color grey900 = Color(0xFF141414);

  // Neutral — Grey (semi-transparent)
  static const Color grey300T40 = Color(0x666D6D6E);
  static const Color grey300T70 = Color(0xB36D6D6E);
  static const Color grey600T60 = Color(0x99333333);

  // Transparent White
  static const Color transparentWhite15 = Color(0x26FFFFFF);
  static const Color transparentWhite20 = Color(0x33FFFFFF);
  static const Color transparentWhite30 = Color(0x4DFFFFFF);
  static const Color transparentWhite35 = Color(0x59FFFFFF);
  static const Color transparentWhite50 = Color(0x80FFFFFF);
  static const Color transparentWhite70 = Color(0xB3FFFFFF);

  // Transparent Black
  static const Color transparentBlack30 = Color(0x4D000000);
  static const Color transparentBlack60 = Color(0x99000000);
  static const Color transparentBlack90 = Color(0xE6000000);
}
