import 'package:flutter/material.dart';

import 'config/display_theme_registry.dart';

export 'config/display_theme_registry.dart'
    show
        DisplayThemeOption,
        kDisplayThemeGraphiteAmber,
        kDisplayThemeNavyCoral,
        kDisplayThemeOptions,
        normalizeDisplayThemeId,
        registeredDisplayThemeIds,
        themeDataForDashboardKvValue,
        themeDataForNormalizedDisplayThemeId;
export 'config/palettes/navy_coral_palette.dart' show NavyCoralPalette;
export 'display_text_scale_kv.dart'
    show
        DisplayTextScaleOption,
        kDisplayTextScaleNormal,
        kDisplayTextScaleScreenKvKey,
        kDisplayTextScaleSelectOptions,
        kDisplayTextScaleTickerKvKey,
        kDisplayTextScaleXLarge,
        linearFactorForDisplayTextScaleKvValue,
        normalizeDisplayTextScaleOption;
export 'display_theme_kv.dart'
    show kDefaultDisplayThemeId, kDisplayThemeIdKvKey;
export 'theme_palette_extension.dart' show PaletteTertiaryLayers;

/// Applies [DisplayTheme.textScale] on top of the platform [TextScaler] (accessibility, etc.).
@immutable
final class DisplayTextScaler extends TextScaler {
  const DisplayTextScaler(this.wrapped, this.displayFactor)
    : assert(displayFactor >= 0);

  final TextScaler wrapped;
  final double displayFactor;

  @override
  double scale(double fontSize) => wrapped.scale(fontSize) * displayFactor;

  @override
  @Deprecated('Use scale() or a linear TextScaler where possible.')
  double get textScaleFactor => wrapped.textScaleFactor * displayFactor;

  @override
  bool operator ==(Object other) {
    return other is DisplayTextScaler &&
        other.wrapped == wrapped &&
        other.displayFactor == displayFactor;
  }

  @override
  int get hashCode => Object.hash(wrapped, displayFactor);
}

/// TV display theming: color presets live under `lib/theme/config/`.
class DisplayTheme {
  const DisplayTheme._();

  /// Extra linear multiplier for on-screen text (composed in [WaddleRoot] via [MediaQuery]).
  static const double textScale = 1.2;

  /// Use under [MaterialApp.builder] so all [Text] respects [textScale].
  static TextScaler wrapTextScaler(TextScaler platform) =>
      DisplayTextScaler(platform, textScale);

  /// Builds the active [ThemeData] for [themeId] (normalized).
  static ThemeData buildForId(String themeId) {
    return themeDataForNormalizedDisplayThemeId(
      normalizeDisplayThemeId(themeId),
    );
  }

  /// Default navy/coral preset (same as [buildForId] with default id).
  static ThemeData build() =>
      themeDataForNormalizedDisplayThemeId(kDisplayThemeNavyCoral);

  /// Resolves theme from a raw [config_key_values] value.
  static ThemeData buildFromKvValue(String? value) =>
      themeDataForDashboardKvValue(value);
}
