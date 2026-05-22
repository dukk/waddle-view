import 'package:flutter/material.dart';
import 'package:waddle_shared/theme/display_custom_themes.dart';

import 'display_background_fill.dart';
import 'display_theme_palette.dart';
import 'nine_color_display_theme_builder.dart';

Color _colorFromHex(String hex) {
  final normalized = hex.trim().toUpperCase();
  final value = normalized.startsWith('#')
      ? normalized.substring(1)
      : normalized;
  return Color(int.parse('FF$value', radix: 16));
}

List<Color> _colorsFromHexList(List<String> hexes) =>
    hexes.map(_colorFromHex).toList();

DisplayBackgroundFill _fillFromStops(List<Color> stops) {
  final gradient = stops.length >= 2 ? stops : [stops.first, stops.first];
  return DisplayBackgroundFill(
    solidColor: gradient.first,
    gradientColors: gradient,
  );
}

/// Builds [DisplayThemePalette] from operator chrome groups.
DisplayThemePalette displayThemePaletteFromChromeGroups(
  DisplayThemeChromeGroups chrome,
) {
  final display = _colorsFromHexList(chrome.display);
  final primary = _colorsFromHexList(chrome.primaryContainer);
  final secondary = _colorsFromHexList(chrome.secondaryContainer);
  final accents = _colorsFromHexList(chrome.accents);

  final primaryForeground = primary.first;
  final primaryGradientStops = primary.length > 1
      ? primary.sublist(1)
      : [primaryForeground];
  final primaryBackground = primaryGradientStops.first;

  final secondaryForeground = secondary.first;
  final secondaryGradientStops = secondary.length > 1
      ? secondary.sublist(1)
      : [secondaryForeground];
  final secondaryBackground = secondaryGradientStops.first;

  final footerBar = Color.lerp(display.first, display.last, 0.55)!;
  final midDark = primaryBackground;
  final mid = secondaryGradientStops.length > 1
      ? secondaryGradientStops[1]
      : secondaryBackground;

  return DisplayThemePalette(
    neutrals: [display.first, footerBar, midDark, mid, primaryForeground],
    accents: accents,
    displayBackground: display.first,
    displayBackgroundFill: _fillFromStops(display),
    primaryContainerBackground: primaryBackground,
    primaryContainerForeground: primaryForeground,
    primaryContainerFill: _fillFromStops(primaryGradientStops),
    secondaryContainerBackground: secondaryBackground,
    secondaryContainerForeground: secondaryForeground,
    secondaryContainerFill: _fillFromStops(secondaryGradientStops),
  );
}

ThemeData buildCustomDisplayTheme(DisplayCustomTheme theme) {
  return buildNineColorDisplayTheme(
    displayThemePaletteFromChromeGroups(theme.chrome),
  );
}
