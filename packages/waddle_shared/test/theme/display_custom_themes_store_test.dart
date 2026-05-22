import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/theme/display_custom_themes.dart';
import 'package:waddle_shared/theme/display_custom_themes_store.dart';
import 'package:waddle_shared/theme/display_theme_ids.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';

import '../helpers/memory_database.dart';

DisplayThemeChromeGroups _sampleChrome() => const DisplayThemeChromeGroups(
      display: ['#0D1B2A', '#1B263B'],
      primaryContainer: ['#E0E1DD', '#1B263B', '#415A77'],
      secondaryContainer: ['#E0E1DD', '#415A77', '#778DA9'],
      accents: ['#83AF84', '#E05C6C', '#FFE356', '#966CB3'],
    );

void main() {
  test('create update delete custom theme and reset active id', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayThemeIdKvKey,
            value: 'custom_aurora',
          ),
        );

    final created = await createDisplayCustomTheme(
      db,
      label: 'Aurora',
      chrome: _sampleChrome(),
    );
    expect(created.id, startsWith('custom_'));
    expect((await readDisplayCustomThemes(db)).length, 1);

    final updated = await updateDisplayCustomTheme(
      db,
      created.id,
      label: 'Aurora Borealis',
    );
    expect(updated.label, 'Aurora Borealis');

    await deleteDisplayCustomTheme(db, created.id);
    expect(await readDisplayCustomThemes(db), isEmpty);

    final active = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(kDisplayThemeIdKvKey)))
        .getSingle();
    expect(active.value, kDefaultDisplayThemeId);
  });

  test('create rejects builtin id and limit', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);

    expect(
      () => updateDisplayCustomTheme(db, kDisplayThemeNavyCoral, label: 'X'),
      throwsA(isA<DisplayThemeValidationException>()),
    );
    expect(
      () => deleteDisplayCustomTheme(db, 'missing_custom'),
      throwsA(isA<DisplayThemeValidationException>()),
    );

    for (var i = 0; i < kDisplayCustomThemeMaxCount; i++) {
      await createDisplayCustomTheme(
        db,
        label: 'Theme $i',
        chrome: _sampleChrome(),
      );
    }
    expect(
      () => createDisplayCustomTheme(
        db,
        label: 'One too many',
        chrome: _sampleChrome(),
      ),
      throwsA(isA<DisplayThemeValidationException>()),
    );
  });

  test('displayCustomThemesToJson maps themes', () {
    const theme = DisplayCustomTheme(
      id: 'custom_test',
      label: 'Test',
      chrome: DisplayThemeChromeGroups(
        display: ['#000000', '#111111'],
        primaryContainer: ['#FFFFFF', '#222222', '#333333'],
        secondaryContainer: ['#FFFFFF', '#444444', '#555555'],
        accents: ['#666666', '#777777', '#888888', '#999999'],
      ),
    );
    final json = displayCustomThemesToJson([theme]);
    expect(json.single['id'], 'custom_test');
    expect(json.single['label'], 'Test');
  });
}
