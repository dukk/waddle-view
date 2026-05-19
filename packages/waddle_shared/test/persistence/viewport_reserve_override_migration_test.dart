import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 32 to 33 adds nullable viewport reserve override columns', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE curator_configurations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  layer TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  program_duration_seconds INTEGER NOT NULL DEFAULT 180,
  history_depth INTEGER NOT NULL DEFAULT 5,
  require_news_photo_for_screens INTEGER NOT NULL DEFAULT 1,
  ticker_enabled INTEGER NOT NULL DEFAULT 1,
  ticker_program_duration_seconds INTEGER NOT NULL DEFAULT 300,
  ticker_pixels_per_second INTEGER NOT NULL DEFAULT 80,
  theme_id_override TEXT,
  default_config INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute(
        "INSERT INTO curator_configurations (id, name, layer) "
        "VALUES ('evening', 'Evening', 'base')",
      );
      raw.execute('PRAGMA user_version = 32');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final row = await (db.select(db.curatorConfigurations)
          ..where((t) => t.id.equals('evening')))
        .getSingle();
    expect(row.viewportReserveTopPctOverride, isNull);
    expect(row.viewportReserveRightPctOverride, isNull);
    expect(row.viewportReserveBottomPctOverride, isNull);
    expect(row.viewportReserveLeftPctOverride, isNull);

    await db.close();
  });
}
