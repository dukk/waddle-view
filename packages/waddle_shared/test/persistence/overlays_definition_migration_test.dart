import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';

const _kLegacyOverlaysDdl = '''
CREATE TABLE overlays (
  id TEXT NOT NULL PRIMARY KEY,
  overlay_type TEXT NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT,
  example_config_json TEXT,
  repeat_annually INTEGER NOT NULL DEFAULT 1,
  year_exact INTEGER,
  start_month INTEGER NOT NULL,
  start_day INTEGER NOT NULL,
  end_month INTEGER,
  end_day INTEGER,
  nth_week_of_month INTEGER,
  nth_weekday INTEGER,
  CHECK (repeat_annually IN (0, 1))
);
''';

void main() {
  test('schema 17 to 18 migrates overlays to name-only definition rows', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_kLegacyOverlaysDdl);
      raw.execute(
        "INSERT INTO overlays (id, overlay_type, label, config_json, "
        "repeat_annually, start_month, start_day) "
        "VALUES ('legacy_row', 'hearts_rain', 'Legacy hearts', '{}', 1, 5, 13)",
      );
      raw.execute('PRAGMA user_version = 17');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final rows = await fetchDisplayOverlays(db);
    expect(rows, hasLength(1));
    expect(rows.single.id, 'legacy_row');
    expect(rows.single.name, 'Legacy hearts');
    expect(rows.single.overlayType, 'hearts_rain');

    final cols = await db.customSelect('PRAGMA table_info(overlays)').get();
    final names = cols.map((r) => r.read<String>('name')).toList();
    expect(names, contains('name'));
    expect(names, isNot(contains('label')));
    expect(names, isNot(contains('start_month')));

    await db.close();
  });
}
