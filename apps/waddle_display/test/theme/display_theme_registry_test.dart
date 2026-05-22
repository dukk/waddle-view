import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/theme/config/display_theme_registry.dart';
import 'package:waddle_shared/theme/display_custom_themes.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart'
    show
        encodeDisplayCustomThemes,
        kDefaultDisplayThemeId,
        kDisplayThemeCustomKvKey,
        kDisplayThemeIdKvKey;

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

  test('registeredDisplayThemeIds includes 15 presets', () {
    expect(registeredDisplayThemeIds, hasLength(15));
    expect(
      registeredDisplayThemeIds,
      containsAll([
        kDisplayThemeNavyCoral,
        kDisplayThemeGraphiteAmber,
        kDisplayThemeTealGoldSunset,
        kDisplayThemeOceanDepth,
        kDisplayThemeWarmMinimal,
        kDisplayThemeMorningCoffee,
        kDisplayThemeDarkNight,
        kDisplayThemeSunnyDay,
      ]),
    );
  });

  test('themeDataForNormalizedDisplayThemeId returns ThemeData for each registered id', () {
    for (final id in registeredDisplayThemeIds) {
      final t = themeDataForNormalizedDisplayThemeId(id);
      expect(t.useMaterial3, isTrue);
      expect(t.colorScheme.brightness, Brightness.dark);
    }
  });

  test('themeDataForNormalizedDisplayThemeId falls back to default when id unknown', () {
    final unknown = themeDataForNormalizedDisplayThemeId('__no_such_theme__');
    final navy = themeDataForNormalizedDisplayThemeId(kDisplayThemeNavyCoral);
    expect(unknown.colorScheme.primary, navy.colorScheme.primary);
  });

  test('themeDataForDisplayThemeId builds custom theme from chrome groups', () {
    const custom = [
      DisplayCustomTheme(
        id: 'custom_test_palette',
        label: 'Test',
        chrome: DisplayThemeChromeGroups(
          display: ['#0D1B2A', '#1B263B'],
          primaryContainer: ['#E0E1DD', '#1B263B'],
          secondaryContainer: ['#E0E1DD', '#415A77', '#778DA9'],
          accents: ['#83AF84', '#E05C6C', '#FFE356', '#966CB3'],
        ),
      ),
    ];
    final t = themeDataForDisplayThemeId('custom_test_palette', customThemes: custom);
    expect(t.brightness, Brightness.dark);
    expect(t.useMaterial3, isTrue);
  });

  test('themeDataForDashboardKv resolves custom catalog', () {
    final kv = {
      kDisplayThemeIdKvKey: 'custom_kv_theme',
      kDisplayThemeCustomKvKey: encodeDisplayCustomThemes([
        const DisplayCustomTheme(
          id: 'custom_kv_theme',
          label: 'KV',
          chrome: DisplayThemeChromeGroups(
            display: ['#000000', '#111111'],
            primaryContainer: ['#FFFFFF', '#222222'],
            secondaryContainer: ['#FFFFFF', '#333333'],
            accents: ['#444444', '#555555', '#666666', '#777777'],
          ),
        ),
      ]),
    };
    final t = themeDataForDashboardKv(kv);
    expect(t.brightness, Brightness.dark);
  });
}
