import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/theme/config/display_theme_registry.dart';
import 'package:waddle_view/theme/display_theme_kv.dart';

void main() {
  test('normalizeDisplayThemeId trims and maps unknown to default', () {
    expect(normalizeDisplayThemeId(null), kDefaultDisplayThemeId);
    expect(normalizeDisplayThemeId(''), kDefaultDisplayThemeId);
    expect(normalizeDisplayThemeId('  '), kDefaultDisplayThemeId);
    expect(normalizeDisplayThemeId('not_a_real_theme'), kDefaultDisplayThemeId);
  });

  test('normalizeDisplayThemeId accepts known ids with case/spacing variants', () {
    expect(normalizeDisplayThemeId('NAVY_CORAL'), kDisplayThemeNavyCoral);
    expect(normalizeDisplayThemeId('navy-coral'), kDisplayThemeNavyCoral);
    expect(
      normalizeDisplayThemeId(' Graphite_Amber '),
      kDisplayThemeGraphiteAmber,
    );
  });

  test('themeDataForNormalizedDisplayThemeId returns ThemeData for each registered id', () {
    for (final id in registeredDisplayThemeIds) {
      final t = themeDataForNormalizedDisplayThemeId(id);
      expect(t.useMaterial3, isTrue);
      expect(t.colorScheme.brightness, Brightness.dark);
    }
  });
}
