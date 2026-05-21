import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/tables/curator_configurations_seed.dart';

const _kLegacyCuratorConfigurationsDdl = '''
CREATE TABLE curator_configurations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  layer TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  program_duration_seconds INTEGER NOT NULL DEFAULT 180,
  history_depth INTEGER NOT NULL DEFAULT 5,
  require_news_photo_for_screens INTEGER NOT NULL DEFAULT 1,
  theme_id_override TEXT,
  default_config INTEGER NOT NULL DEFAULT 0
);
''';

void main() {
  test('schema 11 to 12 adds curator_configurations.ticker_enabled default true', () async {
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
  theme_id_override TEXT,
  default_config INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute(
        "INSERT INTO curator_configurations (id, name, layer) "
        "VALUES ('evening', 'Evening', 'base')",
      );
      raw.execute('PRAGMA user_version = 11');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final row = await db.customSelect(
      'SELECT ticker_enabled FROM curator_configurations WHERE id = ?',
      variables: [Variable<String>('evening')],
    ).getSingle();
    expect(row.read<int>('ticker_enabled'), 1);

    await db.close();
  });

  test(
    'schema 14 without ticker_enabled column upgrades and reads bootstrap row',
    () async {
      final executor = NativeDatabase.memory(setup: (raw) {
        raw.execute(_kLegacyCuratorConfigurationsDdl);
        raw.execute(
          "INSERT INTO curator_configurations (id, name, layer) "
          "VALUES ('bootstrap', 'Bootstrap / adoption', 'exclusive')",
        );
        raw.execute('PRAGMA user_version = 14');
      });
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      final row = await (db.select(db.curatorConfigurations)
            ..where((t) => t.id.equals('bootstrap')))
          .getSingle();
      expect(row.tickerEnabled, isTrue);

      await db.close();
    },
  );

  test(
    'schema 14 with null ticker_enabled backfills before seed reads',
    () async {
      final executor = NativeDatabase.memory(setup: (raw) {
        raw.execute(_kLegacyCuratorConfigurationsDdl);
        raw.execute(
          'ALTER TABLE curator_configurations '
          'ADD COLUMN ticker_enabled INTEGER',
        );
        raw.execute(
          "INSERT INTO curator_configurations (id, name, layer) "
          "VALUES ('bootstrap', 'Bootstrap / adoption', 'exclusive')",
        );
        raw.execute('PRAGMA user_version = 14');
      });
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      await expectLater(
        ensureDefaultCuratorConfigurations(db),
        completes,
      );

      await db.close();
    },
  );

  test(
    'schema 17 with null ticker_enabled backfills on open without upgrade',
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
  ticker_enabled INTEGER,
  ticker_program_duration_seconds INTEGER NOT NULL DEFAULT 300,
  theme_id_override TEXT,
  default_config INTEGER NOT NULL DEFAULT 0
);
''');
        raw.execute(
          "INSERT INTO curator_configurations (id, name, layer) "
          "VALUES ('bootstrap', 'Bootstrap / adoption', 'exclusive')",
        );
        raw.execute('PRAGMA user_version = 17');
      });
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      final row = await (db.select(db.curatorConfigurations)
            ..where((t) => t.id.equals('bootstrap')))
          .getSingle();
      expect(row.tickerEnabled, isTrue);

      await db.close();
    },
  );

  test(
    'schema 16 to 17 adds curator_configurations.ticker_program_duration_seconds default 300',
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
          "VALUES ('evening', 'Evening', 'base')",
        );
        raw.execute('PRAGMA user_version = 16');
      });
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      final row = await db.customSelect(
        'SELECT ticker_program_duration_seconds FROM curator_configurations WHERE id = ?',
        variables: [Variable<String>('evening')],
      ).getSingle();
      // Schema 42+ stores default 300 as NULL (display KV holds the default).
      expect(
        row.readNullable<int>('ticker_program_duration_seconds') ?? 300,
        300,
      );

      await db.close();
    },
  );

  test(
    'schema 18 to 19 adds curator_configurations.ticker_pixels_per_second default 80',
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
  ticker_program_duration_seconds INTEGER NOT NULL DEFAULT 300,
  theme_id_override TEXT,
  default_config INTEGER NOT NULL DEFAULT 0
);
''');
        raw.execute(
          "INSERT INTO curator_configurations (id, name, layer) "
          "VALUES ('evening', 'Evening', 'base')",
        );
        raw.execute('PRAGMA user_version = 18');
      });
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      final row = await db.customSelect(
        'SELECT ticker_pixels_per_second FROM curator_configurations WHERE id = ?',
        variables: [Variable<String>('evening')],
      ).getSingle();
      expect(
        row.readNullable<int>('ticker_pixels_per_second') ?? 80,
        80,
      );

      await db.close();
    },
  );

  test(
    'schema 18 to 19 migrates curator.ticker.newsPixelsPerSecond KV to all configs',
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
  ticker_program_duration_seconds INTEGER NOT NULL DEFAULT 300,
  theme_id_override TEXT,
  default_config INTEGER NOT NULL DEFAULT 0
);
''');
        raw.execute(
          "INSERT INTO curator_configurations (id, name, layer) "
          "VALUES ('evening', 'Evening', 'base'), ('morning', 'Morning', 'base')",
        );
        raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
        raw.execute(
          "INSERT INTO config_key_values (key, value) "
          "VALUES ('curator.ticker.newsPixelsPerSecond', '95')",
        );
        raw.execute('PRAGMA user_version = 18');
      });
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      final rows = await db.customSelect(
        "SELECT id, ticker_pixels_per_second FROM curator_configurations "
        "WHERE id IN ('evening', 'morning') ORDER BY id",
      ).get();
      expect(rows, hasLength(2));
      for (final row in rows) {
        expect(row.read<int>('ticker_pixels_per_second'), 95);
      }

      await db.close();
    },
  );
}
