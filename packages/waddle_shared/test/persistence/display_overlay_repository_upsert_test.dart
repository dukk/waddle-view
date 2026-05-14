import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/display_overlay_schedule_row.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';

void main() {
  test('upsert hearts_rain forces config_json to {}', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);
    await upsertOverlaySchedule(
      db,
      id: 'h1',
      enabled: true,
      overlayKind: kOverlayKindHeartsRain,
      label: 'l',
      messagesJson: '["x"]',
      configJson: '{"density":1}',
      repeatAnnually: true,
      startMonth: 3,
      startDay: 1,
    );
    final rows = await fetchDisplayOverlaySchedules(db);
    expect(rows.single.configJson, '{}');
    expect(rows.single.configJsonSchema, isNotNull);
    expect(rows.single.exampleConfigJson, isNotNull);
    await db.close();
  });

  test('upsert birthday_confetti stores normalized config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);
    await upsertOverlaySchedule(
      db,
      id: 'b1',
      enabled: true,
      overlayKind: kOverlayKindBirthdayConfetti,
      label: 'birthday',
      messagesJson: '["Party"]',
      configJson:
          '{"shapes":["rect"],"colors":["#ABCDEF"],"density":0.2,"message_interval_sec":15}',
      repeatAnnually: true,
      startMonth: 8,
      startDay: 15,
    );
    final rows = await fetchDisplayOverlaySchedules(db);
    expect(rows.single.configJson, contains('"rect"'));
    expect(rows.single.configJson, contains('#ABCDEF'));
    expect(rows.single.configJsonSchema, contains('BirthdayConfettiOverlayConfig'));
    await db.close();
  });

  test('upsert bouncing_message stores normalized config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);
    await upsertOverlaySchedule(
      db,
      id: 'bounce1',
      enabled: true,
      overlayKind: kOverlayKindBouncingMessage,
      label: 'bounce',
      messagesJson: '["Hi there"]',
      configJson:
          '{"color":"#ABCDEF","font_size":28,"font_weight":"700","speed":1.2}',
      repeatAnnually: true,
      startMonth: 3,
      startDay: 20,
    );
    final rows = await fetchDisplayOverlaySchedules(db);
    expect(rows.single.configJson, contains('#ABCDEF'));
    expect(rows.single.configJsonSchema, contains('BouncingMessageOverlayConfig'));
    await db.close();
  });

  test('upsert bouncing_message rejects invalid config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);
    expect(
      () => upsertOverlaySchedule(
        db,
        id: 'bad_bounce',
        enabled: true,
        overlayKind: kOverlayKindBouncingMessage,
        label: 'x',
        messagesJson: '["a"]',
        configJson: '{"font_size":12,"nope":1}',
        repeatAnnually: true,
        startMonth: 4,
        startDay: 1,
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'invalid_config_json',
        ),
      ),
    );
    await db.close();
  });

  test('upsertOverlaySchedule rejects unsupported overlay_kind', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);
    expect(
      () => upsertOverlaySchedule(
        db,
        id: 'z1',
        enabled: true,
        overlayKind: 'laser_show',
        label: '',
        messagesJson: '[]',
        configJson: '{}',
        repeatAnnually: true,
        startMonth: 1,
        startDay: 2,
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'unsupported_overlay_kind',
        ),
      ),
    );
    await db.close();
  });

  test('overlayScheduleToJson decodes messages_json and config_json', () {
    final row = DisplayOverlayScheduleRow(
      id: 'j',
      enabled: true,
      overlayKind: kOverlayKindBirthdayConfetti,
      label: 'lb',
      messagesJson: '["a","b"]',
      configJson: '{"shapes":["star"]}',
      configJsonSchema: '{"type":"object"}',
      exampleConfigJson: '{"shapes":["mix"]}',
      repeatAnnually: true,
      yearExact: null,
      startMonth: 1,
      startDay: 2,
      endMonth: null,
      endDay: null,
      nthWeekOfMonth: null,
      nthWeekday: null,
    );
    final j = overlayScheduleToJson(row);
    expect(j['messages_json'], ['a', 'b']);
    expect(j['config_json'], {'shapes': ['star']});
    expect(j['config_json_schema'], {'type': 'object'});
    expect(j['example_config_json'], {'shapes': ['mix']});
  });
}
