import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

const _kCuratorConfigurationsV42Ddl = '''
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
  viewport_reserve_top_pct_override INTEGER,
  viewport_reserve_right_pct_override INTEGER,
  viewport_reserve_bottom_pct_override INTEGER,
  viewport_reserve_left_pct_override INTEGER,
  default_config INTEGER NOT NULL DEFAULT 0
);
''';

const _kCuratorConfigurationMembersDdl = '''
CREATE TABLE curator_configuration_members (
  configuration_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  PRIMARY KEY (configuration_id, entity_type, entity_id)
);
''';

void main() {
  test('schema 42 to 43 adds default base curator and parent links', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_kCuratorConfigurationsV42Ddl);
      raw.execute(_kCuratorConfigurationMembersDdl);
      raw.execute(
        "INSERT INTO curator_configurations (id, name, layer, sort_order) "
        "VALUES ('evening', 'Evening', 'base', 40)",
      );
      raw.execute(
        "INSERT INTO curator_configurations (id, name, layer, sort_order) "
        "VALUES ('morning', 'Morning', 'base', 20)",
      );
      raw.execute(
        'INSERT INTO curator_configuration_members '
        "(configuration_id, entity_type, entity_id) VALUES ('evening', 'screen', 'clock_digital')",
      );
      raw.execute(
        'INSERT INTO curator_configuration_members '
        "(configuration_id, entity_type, entity_id) VALUES ('evening', 'ticker', 'ticker_time')",
      );
      raw.execute(
        'INSERT INTO curator_configuration_members '
        "(configuration_id, entity_type, entity_id) VALUES ('evening', 'screen', 'jokes')",
      );
      raw.execute('PRAGMA user_version = 42');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final defaultRow = await (db.select(db.curatorConfigurations)
          ..where((t) => t.id.equals(kDefaultBaseCuratorConfigurationId)))
        .getSingle();
    expect(defaultRow.name, 'Default');
    expect(defaultRow.layer, kCuratorLayerBase);
    expect(defaultRow.parentConfigurationId, isNull);

    final evening = await (db.select(db.curatorConfigurations)
          ..where((t) => t.id.equals('evening')))
        .getSingle();
    expect(
      evening.parentConfigurationId,
      kDefaultBaseCuratorConfigurationId,
    );

    final eveningScreens = await (db.select(db.curatorConfigurationMembers)
          ..where((t) => t.configurationId.equals('evening'))
          ..where((t) => t.entityType.equals(kCuratorMemberEntityScreen)))
        .get();
    expect(
      eveningScreens.map((m) => m.entityId),
      ['jokes'],
    );

    final defaultMembers = await db.select(db.curatorConfigurationMembers).get();
    expect(
      defaultMembers.where((m) => m.configurationId == kDefaultBaseCuratorConfigurationId),
      hasLength(2),
    );

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);

    await db.close();
  });
}
