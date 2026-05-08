import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_display/persistence/database.dart';

import '../helpers/legacy_migration_schema_stubs.dart';

void main() {
  test(
    'v19 to v20 renames extra_json to config_json and backfills documentation columns',
    () async {
      final raw = sqlite.sqlite3.openInMemory();
      raw.execute('PRAGMA foreign_keys = ON;');
      raw.execute('''
CREATE TABLE provider_settings (
  id TEXT NOT NULL PRIMARY KEY,
  provider_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  base_url TEXT,
  extra_json TEXT
);
''');
      raw.execute(
        "INSERT INTO provider_settings "
        "VALUES ('jokes','jokes',1,60,NULL,'{\"jokesPerDay\":1}');",
      );
      raw.execute('''
CREATE TABLE screen_definitions (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1,
  layout_json TEXT NOT NULL DEFAULT '{"v":1,"layout":"single","widgets":[]}',
  dwell_seconds INTEGER NOT NULL DEFAULT 10,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  min_gap_between_shows_seconds INTEGER NOT NULL DEFAULT 0,
  min_placements_per_program INTEGER NOT NULL DEFAULT 0,
  max_placements_per_program INTEGER,
  data_key TEXT NOT NULL DEFAULT ''
);
''');
      raw.execute(
        "INSERT INTO screen_definitions (id, name, layout_json) "
        "VALUES ('s', 'Test', '{}');",
      );
      raw.execute('PRAGMA user_version = 19;');
      stubContentCategoriesForMigration(raw);
      stubCalendarEventsAndBlobMetadataForMigration(raw);

      final db = AppDatabase(NativeDatabase.opened(raw));
      await db.customStatement('SELECT 1');

      final pragmaCols = await db
          .customSelect('PRAGMA table_info(provider_settings);')
          .get();
      final colNames = pragmaCols.map((r) => r.read<String>('name')).toSet();
      expect(colNames.contains('config_json'), isTrue);
      expect(colNames.contains('extra_json'), isFalse);

      final ps =
          await (db.select(db.providerSettings)
                ..where((t) => t.id.equals('jokes')))
              .getSingle();
      expect(ps.configJson, '{"jokesPerDay":1}');
      expect(ps.configJsonSchema, isNotNull);
      expect(ps.exampleConfigJson, isNotNull);
      jsonDecode(ps.configJsonSchema!);
      jsonDecode(ps.exampleConfigJson!);

      final scr =
          await (db.select(db.screenDefinitions)
                ..where((t) => t.id.equals('s')))
              .getSingle();
      expect(scr.screenType, 'static_text');
      expect(scr.configJson, '{}');
      expect(scr.configJsonSchema, isNotNull);
      expect(scr.exampleConfigJson, isNotNull);
      jsonDecode(scr.configJsonSchema!);
      jsonDecode(scr.exampleConfigJson!);

      final screenCols = await db
          .customSelect('PRAGMA table_info(screen_definitions);')
          .get();
      final screenColNames =
          screenCols.map((r) => r.read<String>('name')).toSet();
      expect(screenColNames.contains('layout_json'), isFalse);
      expect(screenColNames.contains('screen_type'), isTrue);
      expect(screenColNames.contains('config_json'), isTrue);

      await db.close();
    },
  );
}
