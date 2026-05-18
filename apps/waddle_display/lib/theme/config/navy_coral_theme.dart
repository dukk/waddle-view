import 'package:flutter/material.dart';

import 'display_theme_palette.dart';
import 'nine_color_display_theme_builder.dart';
import 'palettes/navy_coral_palette.dart';

ThemeData buildNavyCoralDisplayTheme() {
  return buildNineColorDisplayTheme(
    DisplayThemePalette(
      neutrals: const [
        NavyCoralPalette.inkBlack,
        NavyCoralPalette.prussianBlue,
        NavyCoralPalette.duskBlue,
        NavyCoralPalette.dustyDenim,
        NavyCoralPalette.alabasterGrey,
      ],
      accents: NavyCoralPalette.accents,
      displayBackground: NavyCoralPalette.background,
      displayBackgroundFill: NavyCoralPalette.displayBackgroundFill,
      primaryContainerBackground: NavyCoralPalette.primaryContainerBackground,
      primaryContainerForeground: NavyCoralPalette.primaryContainerForeground,
      primaryContainerFill: NavyCoralPalette.primaryContainerFill,
      secondaryContainerBackground: NavyCoralPalette.secondaryContainerBackground,
      secondaryContainerForeground: NavyCoralPalette.secondaryContainerForeground,
      secondaryContainerFill: NavyCoralPalette.secondaryContainerFill,
    ),
  );
}
