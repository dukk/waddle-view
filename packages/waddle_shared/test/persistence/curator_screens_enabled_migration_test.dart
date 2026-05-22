import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test(
    'schema 46 to 47 adds curator_configurations.screens_enabled default true',
    () async {
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
  ticker_program_duration_seconds INTEGER,
  ticker_pixels_per_second INTEGER,
  theme_id_override TEXT,
  default_config INTEGER NOT NULL DEFAULT 0,
  parent_configuration_id TEXT
);
''');
        raw.execute(
          "INSERT INTO curator_configurations (id, name, layer) "
          "VALUES ('evening', 'Evening', 'base')",
        );
        raw.execute('PRAGMA user_version = 46');
      });
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      final row = await db.customSelect(
        'SELECT screens_enabled FROM curator_configurations WHERE id = ?',
        variables: [Variable<String>('evening')],
      ).getSingle();
      expect(row.read<int>('screens_enabled'), 1);

      await db.close();
    },
  );

  test(
    'schema 46 without screens_enabled column upgrades on beforeOpen',
    () async {
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
  theme_id_override TEXT,
  default_config INTEGER NOT NULL DEFAULT 0
);
''');
        raw.execute(
          "INSERT INTO curator_configurations (id, name, layer) "
          "VALUES ('bootstrap', 'Bootstrap / adoption', 'exclusive')",
        );
        raw.execute('PRAGMA user_version = 47');
      });
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      final row = await (db.select(db.curatorConfigurations)
            ..where((t) => t.id.equals('bootstrap')))
          .getSingle();
      expect(row.screensEnabled, isTrue);

      await db.close();
    },
  );

  test(
    'schema 47 with null screens_enabled backfills on open',
    () async {
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
  screens_enabled INTEGER,
  ticker_enabled INTEGER NOT NULL DEFAULT 1,
  theme_id_override TEXT,
  default_config INTEGER NOT NULL DEFAULT 0
);
''');
        raw.execute(
          "INSERT INTO curator_configurations (id, name, layer) "
          "VALUES ('bootstrap', 'Bootstrap / adoption', 'exclusive')",
        );
        raw.execute('PRAGMA user_version = 47');
      });
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      final row = await (db.select(db.curatorConfigurations)
            ..where((t) => t.id.equals('bootstrap')))
          .getSingle();
      expect(row.screensEnabled, isTrue);

      await db.close();
    },
  );
}
