import 'package:flutter/material.dart';
import 'package:waddle_shared/theme/display_theme_ids.dart';

import 'coolors_trending_themes.dart';
import 'graphite_amber_theme.dart';
import 'navy_coral_theme.dart';

export 'package:waddle_shared/theme/display_theme_ids.dart'
    show
        kDisplayThemeDopaminePop,
        kDisplayThemeForestCream,
        kDisplayThemeGraphiteAmber,
        kDisplayThemeHeritageCoast,
        kDisplayThemeNavyCoral,
        kDisplayThemeOceanDepth,
        kDisplayThemePlumEmber,
        kDisplayThemeSageWellness,
        kDisplayThemeSlateCrimson,
        kDisplayThemeTealGoldSunset,
        kDisplayThemeWarmMinimal,
        kDisplayThemeWineEmber,
        normalizeDisplayThemeId;

final Map<String, ThemeData Function()> _displayThemeBuilders = {
  kDisplayThemeNavyCoral: buildNavyCoralDisplayTheme,
  kDisplayThemeGraphiteAmber: buildGraphiteAmberDisplayTheme,
  kDisplayThemeTealGoldSunset: buildTealGoldSunsetDisplayTheme,
  kDisplayThemeOceanDepth: buildOceanDepthDisplayTheme,
  kDisplayThemeForestCream: buildForestCreamDisplayTheme,
  kDisplayThemeHeritageCoast: buildHeritageCoastDisplayTheme,
  kDisplayThemePlumEmber: buildPlumEmberDisplayTheme,
  kDisplayThemeSlateCrimson: buildSlateCrimsonDisplayTheme,
  kDisplayThemeWineEmber: buildWineEmberDisplayTheme,
  kDisplayThemeDopaminePop: buildDopaminePopDisplayTheme,
  kDisplayThemeSageWellness: buildSageWellnessDisplayTheme,
  kDisplayThemeWarmMinimal: buildWarmMinimalDisplayTheme,
};

/// Stable theme ids persisted under the `display.theme.id` config key.
List<String> get registeredDisplayThemeIds =>
    List<String>.unmodifiable(_displayThemeBuilders.keys);

typedef DisplayThemeOption = ({String id, String label});

const List<DisplayThemeOption> kDisplayThemeOptions = [
  (id: kDisplayThemeNavyCoral, label: 'Ink blue multi-accent (default)'),
  (id: kDisplayThemeGraphiteAmber, label: 'Graphite & amber'),
  (id: kDisplayThemeTealGoldSunset, label: 'Teal & gold sunset'),
  (id: kDisplayThemeOceanDepth, label: 'Ocean depth'),
  (id: kDisplayThemeForestCream, label: 'Forest & cream'),
  (id: kDisplayThemeHeritageCoast, label: 'Heritage coast'),
  (id: kDisplayThemePlumEmber, label: 'Plum ember'),
  (id: kDisplayThemeSlateCrimson, label: 'Slate & crimson'),
  (id: kDisplayThemeWineEmber, label: 'Wine ember'),
  (id: kDisplayThemeDopaminePop, label: 'Dopamine pop'),
  (id: kDisplayThemeSageWellness, label: 'Sage wellness'),
  (id: kDisplayThemeWarmMinimal, label: 'Warm minimal'),
];

ThemeData themeDataForNormalizedDisplayThemeId(String id) {
  final builder = _displayThemeBuilders[id];
  if (builder == null) {
    return buildNavyCoralDisplayTheme();
  }
  return builder();
}

ThemeData themeDataForDashboardKvValue(String? value) {
  return themeDataForNormalizedDisplayThemeId(normalizeDisplayThemeId(value));
}
