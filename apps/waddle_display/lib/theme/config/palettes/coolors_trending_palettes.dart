import 'package:flutter/material.dart';

import '../coolors_palette_expand.dart';
import '../nine_color_tv_palette.dart';

/// Coolors trending palettes (https://coolors.co/palettes/trending).
///
/// Each [tv] palette is derived from the five hex colors in the linked Coolors URL.
abstract final class CoolorsTrendingPalettes {
  const CoolorsTrendingPalettes._();

  // https://coolors.co/palette/264653-2a9d8f-e9c46a-f4a261-e76f51
  static final NineColorTvPalette tealGoldSunset = nineColorTvPaletteFromCoolorsFive([
    Color(0xFF264653),
    Color(0xFF2A9D8F),
    Color(0xFFE9C46A),
    Color(0xFFF4A261),
    Color(0xFFE76F51),
  ]);

  // https://coolors.co/palette/03045e-0077b6-00b4d8-90e0ef-caf0f8
  static final NineColorTvPalette oceanDepth = nineColorTvPaletteFromCoolorsFive([
    Color(0xFF03045E),
    Color(0xFF0077B6),
    Color(0xFF00B4D8),
    Color(0xFF90E0EF),
    Color(0xFFCAF0F8),
  ]);

  // https://coolors.co/palette/606c38-283618-fefae0-dda15e-bc6c25
  static final NineColorTvPalette forestCream = nineColorTvPaletteFromCoolorsFive([
    Color(0xFF606C38),
    Color(0xFF283618),
    Color(0xFFFEFAE0),
    Color(0xFFDDA15E),
    Color(0xFFBC6C25),
  ]);

  // https://coolors.co/palette/780000-c1121f-fdf0d5-003049-669bbc
  static final NineColorTvPalette heritageCoast = nineColorTvPaletteFromCoolorsFive([
    Color(0xFF780000),
    Color(0xFFC1121F),
    Color(0xFFFDF0D5),
    Color(0xFF003049),
    Color(0xFF669BBC),
  ]);

  // https://coolors.co/palette/5f0f40-9a031e-fb8b24-e36414-0f4c5c
  static final NineColorTvPalette plumEmber = nineColorTvPaletteFromCoolorsFive([
    Color(0xFF5F0F40),
    Color(0xFF9A031E),
    Color(0xFFFB8B24),
    Color(0xFFE36414),
    Color(0xFF0F4C5C),
  ]);

  // https://coolors.co/palette/2b2d42-8d99ae-edf2f4-ef233c-d90429
  static final NineColorTvPalette slateCrimson = nineColorTvPaletteFromCoolorsFive([
    Color(0xFF2B2D42),
    Color(0xFF8D99AE),
    Color(0xFFEDF2F4),
    Color(0xFFEF233C),
    Color(0xFFD90429),
  ]);

  // https://coolors.co/palette/03071e-370617-6a040f-9d0208-d00000
  static final NineColorTvPalette wineEmber = nineColorTvPaletteFromCoolorsFive([
    Color(0xFF03071E),
    Color(0xFF370617),
    Color(0xFF6A040F),
    Color(0xFF9D0208),
    Color(0xFFD00000),
  ]);

  // https://coolors.co/palette/ff006e-fb5607-ffbe0b-8338ec-3a86ff
  static final NineColorTvPalette dopaminePop = nineColorTvPaletteFromCoolorsFive([
    Color(0xFFFF006E),
    Color(0xFFFB5607),
    Color(0xFFFFBE0B),
    Color(0xFF8338EC),
    Color(0xFF3A86FF),
  ]);

  // https://coolors.co/palette/9caf88-cdd5ae-fefee3-f2e8c6-bbc2a0
  static final NineColorTvPalette sageWellness = nineColorTvPaletteFromCoolorsFive([
    Color(0xFF9CAF88),
    Color(0xFFCDD5AE),
    Color(0xFFFEFEE3),
    Color(0xFFF2E8C6),
    Color(0xFFBBC2A0),
  ]);

  // https://coolors.co/palette/f7f1e8-e8b577-d2691e-8b4513-2f1b14
  static final NineColorTvPalette warmMinimal = nineColorTvPaletteFromCoolorsFive([
    Color(0xFFF7F1E8),
    Color(0xFFE8B577),
    Color(0xFFD2691E),
    Color(0xFF8B4513),
    Color(0xFF2F1B14),
  ]);
}
