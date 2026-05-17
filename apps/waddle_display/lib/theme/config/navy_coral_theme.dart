import 'package:flutter/material.dart';

import 'nine_color_display_theme_builder.dart';
import 'nine_color_tv_palette.dart';
import 'palettes/navy_coral_palette.dart';

ThemeData buildNavyCoralDisplayTheme() {
  return buildNineColorDisplayTheme(
    NineColorTvPalette(
      neutrals: const [
        NavyCoralPalette.inkBlack,
        NavyCoralPalette.prussianBlue,
        NavyCoralPalette.duskBlue,
        NavyCoralPalette.dustyDenim,
        NavyCoralPalette.alabasterGrey,
      ],
      accents: NavyCoralPalette.accents,
    ),
  );
}
