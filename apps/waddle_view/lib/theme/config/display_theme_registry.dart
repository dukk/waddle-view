import 'package:flutter/material.dart';

import '../display_theme_kv.dart';
import 'graphite_amber_theme.dart';
import 'navy_coral_theme.dart';

const String kDisplayThemeNavyCoral = 'navy_coral';
const String kDisplayThemeGraphiteAmber = 'graphite_amber';

final Map<String, ThemeData Function()> _displayThemeBuilders = {
  kDisplayThemeNavyCoral: buildNavyCoralDisplayTheme,
  kDisplayThemeGraphiteAmber: buildGraphiteAmberDisplayTheme,
};

/// Stable ids accepted for [kDisplayThemeIdKvKey].
List<String> get registeredDisplayThemeIds =>
    List<String>.unmodifiable(_displayThemeBuilders.keys);

typedef DisplayThemeOption = ({String id, String label});

const List<DisplayThemeOption> kDisplayThemeOptions = [
  (id: kDisplayThemeNavyCoral, label: 'Ink blue multi-accent (default)'),
  (id: kDisplayThemeGraphiteAmber, label: 'Graphite & amber'),
];

String normalizeDisplayThemeId(String? raw) {
  if (raw == null) {
    return kDefaultDisplayThemeId;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return kDefaultDisplayThemeId;
  }
  final id = trimmed.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  if (_displayThemeBuilders.containsKey(id)) {
    return id;
  }
  return kDefaultDisplayThemeId;
}

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
