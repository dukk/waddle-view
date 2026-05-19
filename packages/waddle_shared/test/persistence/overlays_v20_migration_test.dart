import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';

const _kOverlaysV19Ddl = '''
CREATE TABLE overlays (
  id TEXT NOT NULL PRIMARY KEY,
  overlay_type TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT,
  example_config_json TEXT
);
''';

void main() {
  test('schema 19 to 20 migrates overlay seeds and drops example_config_json', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(_kOverlaysV19Ddl);
      raw.execute(
        "INSERT INTO overlays (id, overlay_type, name, config_json, example_config_json) "
        "VALUES ('default_mothers_day_us', 'hearts_rain', 'Old name', "
        "'{\"messages\":[\"Hi\"]}', '{}')",
      );
      raw.execute(
        "INSERT INTO overlays (id, overlay_type, name, config_json, example_config_json) "
        "VALUES ('default_birthday_example_may_13', 'birthday_confetti', 'Old confetti', "
        "'{}', '{}')",
      );
      raw.execute(
        "INSERT INTO overlays (id, overlay_type, name, config_json, example_config_json) "
        "VALUES ('default_bouncing_message_may_13', 'bouncing_message', 'Old bounce', "
        "'{}', '{}')",
      );
      raw.execute('''
CREATE TABLE curator_configuration_members (
  configuration_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  PRIMARY KEY (configuration_id, entity_type, entity_id)
);
''');
      raw.execute(
        "INSERT INTO curator_configuration_members "
        "(configuration_id, entity_type, entity_id) "
        "VALUES ('waddle_birthday', 'overlay', 'default_birthday_example_may_13')",
      );
      raw.execute('PRAGMA user_version = 19');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final cols = await db.customSelect('PRAGMA table_info(overlays)').get();
    final names = cols.map((r) => r.read<String>('name')).toList();
    expect(names, isNot(contains('example_config_json')));

    final rows = await fetchDisplayOverlays(db);
    final mothers = rows.singleWhere((r) => r.id == kDefaultMothersDayOverlayId);
    expect(mothers.overlayType, kOverlayTypeShapeRain);
    expect(mothers.label, 'Raining Hearts');

    final confetti = rows.singleWhere(
      (r) => r.id == kDefaultBirthdayConfettiOverlayId,
    );
    expect(confetti.label, 'Default Birthday Confetti');

    final bounce = rows.singleWhere(
      (r) => r.id == kDefaultWattleViewsBirthdayMessageOverlayId,
    );
    expect(bounce.label, "Wattle View's Birthday Message!");

    final member = await db.customSelect(
      'SELECT entity_id FROM curator_configuration_members '
      "WHERE configuration_id = 'waddle_birthday' AND entity_type = 'overlay'",
    ).get();
    expect(
      member.map((r) => r.read<String>('entity_id')).toList(),
      contains(kDefaultBirthdayConfettiOverlayId),
    );

    await db.close();
  });
}
