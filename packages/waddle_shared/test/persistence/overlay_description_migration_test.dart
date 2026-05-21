import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_row.dart';

const _kOverlaysV43Ddl = '''
CREATE TABLE overlays (
  id TEXT NOT NULL PRIMARY KEY,
  overlay_type TEXT NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  config_json TEXT NOT NULL DEFAULT '{}'
);
''';

void main() {
  test('schema 43 to 44 adds overlays.description', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_kOverlaysV43Ddl);
      raw.execute(
        "INSERT INTO overlays (id, overlay_type, label, config_json) "
        "VALUES ('party', 'shape_rain', 'Party', '{}')",
      );
      raw.execute('PRAGMA user_version = 43');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final rows = await db.customSelect('SELECT * FROM overlays').get();
    expect(rows, hasLength(1));
    final row = DisplayOverlayRow.fromQueryRow(rows.first);
    expect(row.description, '');

    await db.close();
  });
}
