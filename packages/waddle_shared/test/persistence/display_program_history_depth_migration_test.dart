import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/theme/display_program_history_kv.dart';

void main() {
  test(
    'schema 21 to 22 backfills display.program.history_depth from default curator row',
    () async {
      final executor = NativeDatabase.memory(setup: (raw) {
        raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
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
          "INSERT INTO curator_configurations "
          "(id, name, layer, history_depth, default_config) "
          "VALUES ('day', 'Day', 'base', 7, 1)",
        );
        raw.execute('PRAGMA user_version = 21');
      });
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      final row = await (db.select(db.configKeyValues)
            ..where((t) => t.key.equals(kDisplayProgramHistoryDepthKvKey)))
          .getSingle();
      expect(row.value, '7');

      await db.close();
    },
  );
}
