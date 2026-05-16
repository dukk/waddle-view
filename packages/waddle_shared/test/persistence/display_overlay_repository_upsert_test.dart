import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/display_overlay_schedule_row.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';

void main() {
  test('upsert hearts_rain stores messages in config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlaySchedule(
      db,
      id: 'h1',
      enabled: true,
      overlayType: kOverlayTypeHeartsRain,
      label: 'l',
      configJson: '{"messages":["x"],"ignored":1}',
      repeatAnnually: true,
      startMonth: 3,
      startDay: 1,
    );
    final rows = await fetchDisplayOverlaySchedules(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['messages'], ['x']);
    expect(cfg.containsKey('ignored'), isFalse);
    expect(rows.single.configJsonSchema, isNotNull);
    expect(rows.single.exampleConfigJson, isNotNull);
    await db.close();
  });

  test('upsert birthday_confetti stores normalized config_json with messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlaySchedule(
      db,
      id: 'b1',
      enabled: true,
      overlayType: kOverlayTypeBirthdayConfetti,
      label: 'birthday',
      configJson:
          '{"messages":["Party"],"shapes":["rect"],"colors":["#ABCDEF"],'
          '"density":0.2,"message_interval_sec":15}',
      repeatAnnually: true,
      startMonth: 8,
      startDay: 15,
    );
    final rows = await fetchDisplayOverlaySchedules(db);
    expect(rows.single.configJson, contains('"rect"'));
    expect(rows.single.configJson, contains('#ABCDEF'));
    expect(rows.single.configJson, contains('"Party"'));
    expect(rows.single.configJsonSchema, contains('BirthdayConfettiOverlayConfig'));
    await db.close();
  });

  test('upsert bouncing_message stores normalized config_json with messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlaySchedule(
      db,
      id: 'bounce1',
      enabled: true,
      overlayType: kOverlayTypeBouncingMessage,
      label: 'bounce',
      configJson:
          '{"messages":["Hi there"],"color":"#ABCDEF","font_size":28,'
          '"font_weight":"700","speed":1.2}',
      repeatAnnually: true,
      startMonth: 3,
      startDay: 20,
    );
    final rows = await fetchDisplayOverlaySchedules(db);
    expect(rows.single.configJson, contains('#ABCDEF'));
    expect(rows.single.configJson, contains('"Hi there"'));
    expect(rows.single.configJsonSchema, contains('BouncingMessageOverlayConfig'));
    await db.close();
  });

  test('upsert bouncing_message rejects invalid config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    expect(
      () => upsertOverlaySchedule(
        db,
        id: 'bad_bounce',
        enabled: true,
        overlayType: kOverlayTypeBouncingMessage,
        label: 'x',
        configJson: '{"messages":["a"],"font_size":12,"nope":1}',
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

  test('upsertOverlaySchedule accepts custom overlay_type slug', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlaySchedule(
      db,
      id: 'laser_row',
      enabled: false,
      overlayType: 'laser_show',
      label: 'future',
      configJson: '{"messages":["peek"],"beam":true}',
      repeatAnnually: true,
      startMonth: 1,
      startDay: 2,
    );
    final rows = await fetchDisplayOverlaySchedules(db);
    expect(rows.single.overlayType, 'laser_show');
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['messages'], ['peek']);
    expect(cfg['beam'], isTrue);
    await db.close();
  });

  test('overlayScheduleToJson decodes config_json', () {
    final row = DisplayOverlayScheduleRow(
      id: 'j',
      enabled: true,
      overlayType: kOverlayTypeBirthdayConfetti,
      label: 'lb',
      configJson: '{"shapes":["star"],"messages":["a","b"]}',
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
    expect(j['overlay_type'], kOverlayTypeBirthdayConfetti);
    expect(j['config_json'], {
      'shapes': ['star'],
      'messages': ['a', 'b'],
    });
    expect(j['config_json_schema'], {'type': 'object'});
    expect(j['example_config_json'], {'shapes': ['mix']});
  });
}
