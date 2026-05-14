import 'package:test/test.dart';
import 'package:waddle_shared/theme/display_theme_ids.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';

void main() {
  test('normalizeDisplayThemeId defaults for null, empty, and whitespace', () {
    expect(normalizeDisplayThemeId(null), kDefaultDisplayThemeId);
    expect(normalizeDisplayThemeId(''), kDefaultDisplayThemeId);
    expect(normalizeDisplayThemeId('   '), kDefaultDisplayThemeId);
  });

  test('normalizeDisplayThemeId accepts registered ids case-insensitively', () {
    expect(normalizeDisplayThemeId('NAVY_CORAL'), kDisplayThemeNavyCoral);
    expect(normalizeDisplayThemeId('Graphite-Amber'), kDisplayThemeGraphiteAmber);
    expect(
      normalizeDisplayThemeId('  graphite amber  '),
      kDisplayThemeGraphiteAmber,
    );
  });

  test('normalizeDisplayThemeId maps spaces and hyphens to underscores', () {
    expect(
      normalizeDisplayThemeId('navy coral'),
      kDisplayThemeNavyCoral,
    );
    expect(
      normalizeDisplayThemeId('navy-coral'),
      kDisplayThemeNavyCoral,
    );
  });

  test('unknown id falls back to default theme', () {
    expect(normalizeDisplayThemeId('neon_punk'), kDefaultDisplayThemeId);
    expect(normalizeDisplayThemeId('navy_coral_extra'), kDefaultDisplayThemeId);
  });
}
