import 'package:flutter/material.dart';
import 'package:waddle_shared/theme/display_theme_ids.dart';

import 'graphite_amber_theme.dart';
import 'navy_coral_theme.dart';

export 'package:waddle_shared/theme/display_theme_ids.dart'
    show
        kDisplayThemeGraphiteAmber,
        kDisplayThemeNavyCoral,
        normalizeDisplayThemeId;

final Map<String, ThemeData Function()> _displayThemeBuilders = {
  kDisplayThemeNavyCoral: buildNavyCoralDisplayTheme,
  kDisplayThemeGraphiteAmber: buildGraphiteAmberDisplayTheme,
};

/// Stable theme ids persisted under the `display.theme.id` config key.
List<String> get registeredDisplayThemeIds =>
    List<String>.unmodifiable(_displayThemeBuilders.keys);

typedef DisplayThemeOption = ({String id, String label});

const List<DisplayThemeOption> kDisplayThemeOptions = [
  (id: kDisplayThemeNavyCoral, label: 'Ink blue multi-accent (default)'),
  (id: kDisplayThemeGraphiteAmber, label: 'Graphite & amber'),
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
