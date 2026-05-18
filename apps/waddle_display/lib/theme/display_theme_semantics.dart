import 'package:flutter/material.dart';

import 'config/display_background_fill.dart';
import 'theme_palette_extension.dart';

/// Canonical display theme color accessors for slides and chrome.
extension DisplayThemeSemantics on ThemeData {
  PaletteTertiaryLayers? get _palette => extension<PaletteTertiaryLayers>();

  DisplayBackgroundFill get displayBackgroundFill =>
      _palette?.displayBackgroundFill ??
      DisplayBackgroundFill(solidColor: colorScheme.surface);

  DisplayBackgroundFill get slideChromeFill =>
      _palette?.primaryContainerFill ??
      DisplayBackgroundFill(solidColor: colorScheme.primaryContainer);

  DisplayBackgroundFill get tickerChromeFill =>
      _palette?.secondaryContainerFill ??
      DisplayBackgroundFill(solidColor: colorScheme.secondaryContainer);

  Color get slidePanelColor => colorScheme.primaryContainer;

  Color get slidePanelOnColor => colorScheme.onPrimaryContainer;

  Color get mutedOnSlide => colorScheme.onSurfaceVariant;

  Color get defaultIconColor =>
      _palette?.iconColor ?? colorScheme.onSurfaceVariant;

  Color accent(int index) {
    final palette = _palette;
    if (palette != null) {
      return switch (index) {
        1 => palette.accent1,
        2 => palette.accent2,
        3 => palette.accent3,
        4 => palette.accent4,
        _ => palette.accent1,
      };
    }
    return switch (index) {
      1 => colorScheme.secondary,
      2 => colorScheme.tertiary,
      3 => colorScheme.outline,
      4 => colorScheme.tertiaryContainer,
      _ => colorScheme.secondary,
    };
  }

  Color get progressIndicatorColor =>
      _palette?.accent1 ?? colorScheme.secondary;
}

extension DisplayThemeSemanticsContext on BuildContext {
  ThemeData get displayTheme => Theme.of(this);

  DisplayBackgroundFill get displayBackgroundFill =>
      displayTheme.displayBackgroundFill;

  DisplayBackgroundFill get slideChromeFill => displayTheme.slideChromeFill;

  DisplayBackgroundFill get tickerChromeFill => displayTheme.tickerChromeFill;

  Color get slidePanelColor => displayTheme.slidePanelColor;

  Color get slidePanelOnColor => displayTheme.slidePanelOnColor;

  Color get mutedOnSlide => displayTheme.mutedOnSlide;

  Color get defaultIconColor => displayTheme.defaultIconColor;

  Color accent(int index) => displayTheme.accent(index);

  Color get progressIndicatorColor => displayTheme.progressIndicatorColor;
}
