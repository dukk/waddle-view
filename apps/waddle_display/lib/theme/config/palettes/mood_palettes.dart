import 'package:flutter/material.dart';

import '../coolors_palette_expand.dart';
import '../nine_color_tv_palette.dart';

/// Mood-inspired display palettes (five hex colors expanded for TV chrome).
abstract final class MoodPalettes {
  const MoodPalettes._();

  // Morning coffee: espresso → latte → cream, caramel highlight
  static final NineColorTvPalette morningCoffee =
      nineColorTvPaletteFromCoolorsFive([
    Color(0xFF2C1810),
    Color(0xFF6F4E37),
    Color(0xFFC4A882),
    Color(0xFFF0E6D2),
    Color(0xFFD2691E),
  ]);

  // Dark night: near-black → indigo → moonlit gray → starlight
  static final NineColorTvPalette darkNight = nineColorTvPaletteFromCoolorsFive([
    Color(0xFF0B0C10),
    Color(0xFF1B1B2F),
    Color(0xFF4A4E69),
    Color(0xFF9A8C98),
    Color(0xFFEAE7DC),
  ]);

  // Sunny day: sky → sun/gold → light sky → warm white
  static final NineColorTvPalette sunnyDay = nineColorTvPaletteFromCoolorsFive([
    Color(0xFF0077B6),
    Color(0xFFFFD60A),
    Color(0xFFFFC300),
    Color(0xFF90E0EF),
    Color(0xFFFFF8E7),
  ]);
}
