import 'package:flutter/material.dart';

import 'display_theme_palette.dart';

/// Builds a [DisplayThemePalette] from a Coolors-style 5-color list (dark → light).
DisplayThemePalette displayThemePaletteFromCoolorsFive(List<Color> colors) {
  if (colors.length != 5) {
    throw ArgumentError.value(colors.length, 'colors', 'expected exactly 5 colors');
  }
  final byLuminance = List<Color>.from(colors)
    ..sort((a, b) => a.computeLuminance().compareTo(b.computeLuminance()));

  final background = _tvSurfaceColor(byLuminance[0]);
  final footerBar = _tvSurfaceColor(
    Color.lerp(byLuminance[0], byLuminance[1], 0.55)!,
  );
  final midDark = _tvSurfaceColor(byLuminance[1]);
  final mid = byLuminance[2];
  final lightest = byLuminance[4];
  final primaryText = lightest.computeLuminance() >= 0.42
      ? lightest
      : const Color(0xFFE8E6E3);

  final accents = _fourAccentColors(colors, primaryText);
  final neutrals = [background, footerBar, midDark, mid, primaryText];

  return DisplayThemePalette.fromNeutralsAndAccents(
    neutrals: neutrals,
    accents: accents,
  );
}

/// @deprecated Use [displayThemePaletteFromCoolorsFive].
NineColorTvPalette nineColorTvPaletteFromCoolorsFive(List<Color> colors) =>
    displayThemePaletteFromCoolorsFive(colors);

List<Color> _fourAccentColors(List<Color> colors, Color primaryText) {
  final ranked = List<Color>.from(colors)
    ..removeWhere((c) => c == primaryText)
    ..sort((a, b) => _saturation(b).compareTo(_saturation(a)));

  final accents = <Color>[];
  for (final color in ranked) {
    if (accents.length >= 4) {
      break;
    }
    if (!accents.contains(color)) {
      accents.add(color);
    }
  }
  while (accents.length < 4) {
    final seed = accents.isEmpty ? colors.first : accents.last;
    accents.add(
      Color.lerp(seed, Colors.white, 0.15 * (accents.length + 1))!,
    );
  }
  return accents;
}

double _saturation(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.saturation;
}

Color _tvSurfaceColor(Color color) {
  if (color.computeLuminance() <= 0.12) {
    return color;
  }
  return Color.lerp(color, Colors.black, 0.78)!;
}
