import 'package:flutter/material.dart';
import 'package:waddle_display/theme/config/display_background_fill.dart';
import 'package:waddle_display/theme/theme_palette_extension.dart';

DisplayBackgroundFill sampleBackgroundFill(Color a, Color b) =>
    DisplayBackgroundFill(solidColor: a, gradientColors: [a, b]);

LinearGradient sampleLinearGradient(Color a, Color b) =>
    LinearGradient(colors: [a, b]);

/// Minimal [PaletteTertiaryLayers] for widget tests.
PaletteTertiaryLayers samplePaletteTertiaryLayers({
  Color primary = const Color(0xFF111111),
  Color iconColor = const Color(0xFF222222),
  Color accent1 = const Color(0xFF333333),
  Color accent2 = const Color(0xFF444444),
  Color accent3 = const Color(0xFF555555),
  Color accent4 = const Color(0xFF666666),
  Map<Color, List<Color>> tertiaryLayersByColor = const {},
}) {
  const c1 = Color(0xFF010101);
  const c2 = Color(0xFF020202);
  const c3 = Color(0xFF030303);
  const c4 = Color(0xFF040404);
  final fill12 = sampleBackgroundFill(c1, c2);
  final fill34 = sampleBackgroundFill(c3, c4);
  return PaletteTertiaryLayers(
    primary: primary,
    iconColor: iconColor,
    accent1: accent1,
    accent2: accent2,
    accent3: accent3,
    accent4: accent4,
    colorOrder: const [c1],
    tertiaryLayersByColor: tertiaryLayersByColor,
    displayBackgroundFill: fill12,
    primaryContainerFill: fill12,
    secondaryContainerFill: fill34,
    primaryPairGradient: sampleLinearGradient(c1, c2),
    secondaryPairGradient: sampleLinearGradient(c3, c4),
  );
}
