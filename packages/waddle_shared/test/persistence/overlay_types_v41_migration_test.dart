import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  test('schema 40 to 41 backfills cloud_drift overlay_types catalog row', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE overlay_types (
  overlay_type TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  config_json_schema TEXT
);
''');
      raw.execute(
        "INSERT INTO overlay_types (overlay_type, label) "
        "VALUES ('matrix_rain', 'Matrix rain')",
      );
      raw.execute('PRAGMA user_version = 40');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final rows = await db.select(db.overlayTypes).get();
    final types = rows.map((r) => r.overlayType).toSet();
    expect(types, contains(kOverlayTypeCloudDrift));
    expect(types.length, greaterThanOrEqualTo(kBuiltinOverlayTypes.length));

    await db.close();
  });
}
