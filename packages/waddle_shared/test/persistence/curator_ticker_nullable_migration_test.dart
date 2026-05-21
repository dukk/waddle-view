import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/display/display_ticker_settings.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test(
    'schema 41 to 42 nullable ticker overrides and display ticker KV seed',
    () async {
      final executor = NativeDatabase.memory(
        setup: (raw) {
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
  viewport_reserve_top_pct_override INTEGER,
  viewport_reserve_right_pct_override INTEGER,
  viewport_reserve_bottom_pct_override INTEGER,
  viewport_reserve_left_pct_override INTEGER,
  default_config INTEGER NOT NULL DEFAULT 0
);
''');
          raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
          raw.execute(
            "INSERT INTO curator_configurations (id, name, layer, "
            "ticker_program_duration_seconds, ticker_pixels_per_second) "
            "VALUES ('default', 'Default', 'base', 300, 80)",
          );
          raw.execute(
            "INSERT INTO curator_configurations (id, name, layer, "
            "ticker_program_duration_seconds, ticker_pixels_per_second) "
            "VALUES ('custom', 'Custom', 'base', 420, 95)",
          );
          raw.execute('PRAGMA user_version = 41');
        },
      );
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      final defaultRow = await (db.select(
        db.curatorConfigurations,
      )..where((t) => t.id.equals('default'))).getSingle();
      expect(defaultRow.tickerProgramDurationSeconds, isNull);
      expect(defaultRow.tickerPixelsPerSecond, isNull);

      final customRow = await (db.select(
        db.curatorConfigurations,
      )..where((t) => t.id.equals('custom'))).getSingle();
      expect(customRow.tickerProgramDurationSeconds, 420);
      expect(customRow.tickerPixelsPerSecond, 95);

      final kvRows = await db.select(db.configKeyValues).get();
      final kv = {for (final r in kvRows) r.key: r.value};
      expect(
        kv[kDisplayTickerProgramDurationSecondsKvKey],
        kDisplayTickerProgramDurationSecondsDefault,
      );
      expect(
        kv[kDisplayTickerPixelsPerSecondKvKey],
        kDisplayTickerPixelsPerSecondDefault,
      );

      await db.close();
    },
  );
}
