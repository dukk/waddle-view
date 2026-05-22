import 'package:test/test.dart';
import 'package:waddle_shared/theme/display_custom_themes.dart';
import 'package:waddle_shared/theme/display_theme_ids.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';

DisplayThemeChromeGroups _sampleChrome() => const DisplayThemeChromeGroups(
      display: ['#0D1B2A', '#1B263B'],
      primaryContainer: ['#E0E1DD', '#1B263B', '#415A77'],
      secondaryContainer: ['#E0E1DD', '#415A77', '#778DA9'],
      accents: ['#83AF84', '#E05C6C', '#FFE356', '#966CB3'],
    );

void main() {
  test('parseDisplayThemeChromeGroups validates hex and counts', () {
    final chrome = parseDisplayThemeChromeGroups(_sampleChrome().toJson());
    expect(chrome.display, hasLength(2));
    expect(chrome.accents, hasLength(4));
  });

  test('parseDisplayThemeChromeGroups rejects bad accent count', () {
    expect(
      () => parseDisplayThemeChromeGroups({
        ..._sampleChrome().toJson(),
        'accents': ['#111111', '#222222'],
      }),
      throwsA(isA<DisplayThemeValidationException>()),
    );
  });

  test('resolveDisplayThemeId accepts builtin and custom', () {
    const custom = [
      DisplayCustomTheme(
        id: 'custom_test',
        label: 'Test',
        chrome: DisplayThemeChromeGroups(
          display: ['#000000', '#111111'],
          primaryContainer: ['#FFFFFF', '#222222'],
          secondaryContainer: ['#FFFFFF', '#333333'],
          accents: ['#444444', '#555555', '#666666', '#777777'],
        ),
      ),
    ];
    expect(resolveDisplayThemeId('navy_coral', custom), kDisplayThemeNavyCoral);
    expect(resolveDisplayThemeId('custom_test', custom), 'custom_test');
    expect(resolveDisplayThemeId('missing', custom), kDefaultDisplayThemeId);
    expect(resolveDisplayThemeId('Morning Coffee', const []), kDisplayThemeMorningCoffee);
  });

  test('encode and parse round-trip', () {
    const themes = [
      DisplayCustomTheme(
        id: 'custom_aurora',
        label: 'Aurora',
        chrome: DisplayThemeChromeGroups(
          display: ['#0D1B2A', '#1B263B'],
          primaryContainer: ['#E0E1DD', '#1B263B'],
          secondaryContainer: ['#E0E1DD', '#415A77', '#778DA9'],
          accents: ['#83AF84', '#E05C6C', '#FFE356', '#966CB3'],
        ),
      ),
    ];
    final parsed = parseDisplayCustomThemesFromKvValue(
      encodeDisplayCustomThemes(themes),
    );
    expect(parsed, hasLength(1));
    expect(parsed.first.id, 'custom_aurora');
    expect(parsed.first.chrome.display, ['#0D1B2A', '#1B263B']);
  });

  test('allocateDisplayCustomThemeId avoids collisions', () {
    final id = allocateDisplayCustomThemeId(
      'My Theme',
      {'custom_my_theme', 'navy_coral'},
    );
    expect(id, 'custom_my_theme_2');
  });
}
