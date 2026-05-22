import 'package:flutter/material.dart';
import 'package:waddle_shared/theme/display_custom_themes.dart';
import 'package:waddle_shared/theme/display_theme_ids.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';

import 'coolors_trending_themes.dart';
import 'custom_display_theme_builder.dart';
import 'graphite_amber_theme.dart';
import 'mood_display_themes.dart';
import 'navy_coral_theme.dart';

export 'package:waddle_shared/theme/display_theme_ids.dart'
    show
        kDisplayThemeDarkNight,
        kDisplayThemeDopaminePop,
        kDisplayThemeForestCream,
        kDisplayThemeGraphiteAmber,
        kDisplayThemeHeritageCoast,
        kDisplayThemeMorningCoffee,
        kDisplayThemeNavyCoral,
        kDisplayThemeOceanDepth,
        kDisplayThemePlumEmber,
        kDisplayThemeSageWellness,
        kDisplayThemeSlateCrimson,
        kDisplayThemeSunnyDay,
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
  kDisplayThemeMorningCoffee: buildMorningCoffeeDisplayTheme,
  kDisplayThemeDarkNight: buildDarkNightDisplayTheme,
  kDisplayThemeSunnyDay: buildSunnyDayDisplayTheme,
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
  (id: kDisplayThemeMorningCoffee, label: 'Morning coffee'),
  (id: kDisplayThemeDarkNight, label: 'Dark night'),
  (id: kDisplayThemeSunnyDay, label: 'Sunny day'),
];

ThemeData themeDataForDisplayThemeId(
  String id, {
  List<DisplayCustomTheme> customThemes = const [],
}) {
  final builder = _displayThemeBuilders[id];
  if (builder != null) {
    return builder();
  }
  final custom = findDisplayCustomTheme(customThemes, id);
  if (custom != null) {
    return buildCustomDisplayTheme(custom);
  }
  return buildNavyCoralDisplayTheme();
}

ThemeData themeDataForNormalizedDisplayThemeId(String id) {
  return themeDataForDisplayThemeId(id);
}

ThemeData themeDataForDashboardKv(Map<String, String> kv) {
  final customThemes = parseDisplayCustomThemesFromKvValue(
    kv[kDisplayThemeCustomKvKey],
  );
  final id = resolveDisplayThemeId(kv[kDisplayThemeIdKvKey], customThemes);
  return themeDataForDisplayThemeId(id, customThemes: customThemes);
}

ThemeData themeDataForDashboardKvValue(String? value) {
  return themeDataForNormalizedDisplayThemeId(normalizeDisplayThemeId(value));
}
