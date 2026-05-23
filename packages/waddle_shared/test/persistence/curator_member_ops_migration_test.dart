import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

const _kCuratorConfigurationsV51Ddl = '''
CREATE TABLE curator_configurations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  layer TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  program_duration_seconds INTEGER NOT NULL DEFAULT 180,
  history_depth INTEGER NOT NULL DEFAULT 5,
  require_news_photo_for_screens INTEGER NOT NULL DEFAULT 1,
  screens_enabled INTEGER NOT NULL DEFAULT 1,
  ticker_enabled INTEGER NOT NULL DEFAULT 1,
  default_config INTEGER NOT NULL DEFAULT 0,
  parent_configuration_id TEXT
);
''';

const _kCuratorConfigurationMembersV51Ddl = '''
CREATE TABLE curator_configuration_members (
  configuration_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  PRIMARY KEY (configuration_id, entity_type, entity_id)
);
''';

const _kCuratorScheduleRulesV51Ddl = '''
CREATE TABLE curator_schedule_rules (
  id TEXT NOT NULL PRIMARY KEY,
  configuration_id TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 0,
  days_of_week_mask INTEGER,
  repeat_annually INTEGER NOT NULL DEFAULT 1
);
''';

const _kScreensV51Ddl = '''
CREATE TABLE screens (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  screen_type TEXT NOT NULL,
  config_json TEXT NOT NULL DEFAULT '{}',
  min_dwell_seconds INTEGER NOT NULL DEFAULT 8,
  max_dwell_seconds INTEGER NOT NULL DEFAULT 15,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  min_gap_between_shows_seconds INTEGER NOT NULL DEFAULT 0,
  min_placements_per_program INTEGER NOT NULL DEFAULT 0,
  max_placements_per_program INTEGER,
  data_key TEXT NOT NULL DEFAULT ''
);
''';

void main() {
  test(
    'schema 51 to 52 adds op column, rebalances sort, inserts weekday/weekend',
    () async {
      final executor = NativeDatabase.memory(
        setup: (raw) {
          raw.execute(_kCuratorConfigurationsV51Ddl);
          raw.execute(_kCuratorConfigurationMembersV51Ddl);
          raw.execute(_kCuratorScheduleRulesV51Ddl);
          raw.execute(_kScreensV51Ddl);
          raw.execute(
            "INSERT INTO curator_configurations (id, name, layer, sort_order) "
            "VALUES ('night', 'Night', 'base', 10)",
          );
          raw.execute(
            "INSERT INTO curator_configurations (id, name, layer, sort_order) "
            "VALUES ('waddle_birthday', 'Birthday', 'enhancement', 100)",
          );
          raw.execute(
            "INSERT INTO screens (id, label, screen_type) "
            "VALUES ('news', 'News', 'news')",
          );
          raw.execute(
            'INSERT INTO curator_configuration_members '
            "(configuration_id, entity_type, entity_id) VALUES ('night', 'screen', 'news')",
          );
          raw.execute('PRAGMA user_version = 51');
        },
      );
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await db.customStatement('SELECT 1');

      final night = await (db.select(
        db.curatorConfigurations,
      )..where((t) => t.id.equals('night'))).getSingle();
      expect(night.sortOrder, 100);

      final birthday = await (db.select(
        db.curatorConfigurations,
      )..where((t) => t.id.equals('waddle_birthday'))).getSingle();
      expect(birthday.sortOrder, 200);

      final member = await (db.select(
        db.curatorConfigurationMembers,
      )..where((t) => t.configurationId.equals('night'))).getSingle();
      expect(member.op, kCuratorMemberOpAdd);

      final weekday = await (db.select(
        db.curatorConfigurations,
      )..where((t) => t.id.equals('weekday'))).getSingleOrNull();
      expect(weekday, isNotNull);
      expect(weekday!.sortOrder, 10);

      final screen = await (db.select(
        db.screens,
      )..where((t) => t.id.equals('news'))).getSingle();
      expect(screen.requireNewsPhoto, isTrue);

      await db.close();
    },
  );
}
