import 'package:flutter/material.dart';

import '../theme_palette_extension.dart';
import 'display_background_fill.dart';

String displayThemeColorToHex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

List<String> displayThemeHexList(Iterable<Color> colors) =>
    colors.map(displayThemeColorToHex).toList();

/// Preview groups matching controller [DisplayThemePreviewGroups] shape.
Map<String, List<String>> displayThemePreviewGroupsFromTheme(
  ThemeData theme,
  PaletteTertiaryLayers ext,
) {
  return {
    'display': displayThemeHexList(ext.displayBackgroundFill.gradientColors),
    'primaryContainer': [
      displayThemeColorToHex(theme.colorScheme.onPrimaryContainer),
      ...displayThemeHexList(ext.primaryContainerFill.gradientColors),
    ],
    'secondaryContainer': [
      displayThemeColorToHex(theme.colorScheme.onSecondaryContainer),
      ...displayThemeHexList(ext.secondaryContainerFill.gradientColors),
    ],
    'accents': [
      displayThemeColorToHex(ext.accent1),
      displayThemeColorToHex(ext.accent2),
      displayThemeColorToHex(ext.accent3),
      displayThemeColorToHex(ext.accent4),
    ],
  };
}

Map<String, List<String>> displayThemePreviewGroupsFromPalette({
  required DisplayBackgroundFill displayBackgroundFill,
  required Color primaryContainerForeground,
  required DisplayBackgroundFill primaryContainerFill,
  required Color secondaryContainerForeground,
  required DisplayBackgroundFill secondaryContainerFill,
  required Color accent1,
  required Color accent2,
  required Color accent3,
  required Color accent4,
}) {
  return {
    'display': displayThemeHexList(displayBackgroundFill.gradientColors),
    'primaryContainer': [
      displayThemeColorToHex(primaryContainerForeground),
      ...displayThemeHexList(primaryContainerFill.gradientColors),
    ],
    'secondaryContainer': [
      displayThemeColorToHex(secondaryContainerForeground),
      ...displayThemeHexList(secondaryContainerFill.gradientColors),
    ],
    'accents': [
      displayThemeColorToHex(accent1),
      displayThemeColorToHex(accent2),
      displayThemeColorToHex(accent3),
      displayThemeColorToHex(accent4),
    ],
  };
}
