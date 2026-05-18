import 'package:flutter/material.dart';

import 'display_theme_palette.dart';
import 'nine_color_display_theme_builder.dart';
import 'palettes/graphite_amber_palette.dart';

ThemeData buildGraphiteAmberDisplayTheme() {
  return buildNineColorDisplayTheme(
    DisplayThemePalette(
      neutrals: GraphiteAmberPalette.neutrals,
      accents: GraphiteAmberPalette.accents,
      displayBackground: GraphiteAmberPalette.background,
      displayBackgroundFill: GraphiteAmberPalette.displayBackgroundFill,
      primaryContainerBackground: GraphiteAmberPalette.primaryContainerBackground,
      primaryContainerForeground: GraphiteAmberPalette.primaryContainerForeground,
      primaryContainerFill: GraphiteAmberPalette.primaryContainerFill,
      secondaryContainerBackground: GraphiteAmberPalette.secondaryContainerBackground,
      secondaryContainerForeground: GraphiteAmberPalette.secondaryContainerForeground,
      secondaryContainerFill: GraphiteAmberPalette.secondaryContainerFill,
    ),
  );
}
