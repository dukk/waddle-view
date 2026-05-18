import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/display_overlay_row.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';

void main() {
  test('upsert hearts_rain stores messages in config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'h1',
      overlayType: kOverlayTypeHeartsRain,
      name: 'Hearts',
      configJson: '{"messages":["x"],"ignored":1}',
    );
    final rows = await fetchDisplayOverlays(db);
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
    await upsertOverlay(
      db,
      id: 'b1',
      overlayType: kOverlayTypeBirthdayConfetti,
      name: 'birthday',
      configJson:
          '{"messages":["Party"],"shapes":["rect"],"colors":["#ABCDEF"],'
          '"density":0.2,"message_interval_sec":15}',
    );
    final rows = await fetchDisplayOverlays(db);
    expect(rows.single.configJson, contains('"rect"'));
    expect(rows.single.configJson, contains('#ABCDEF'));
    expect(rows.single.configJson, contains('"Party"'));
    expect(rows.single.configJsonSchema, contains('BirthdayConfettiOverlayConfig'));
    await db.close();
  });

  test('upsert falling_images stores normalized config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'fall1',
      overlayType: kOverlayTypeFallingImages,
      name: 'drops',
      configJson:
          '{"image_blob_keys":["overlay/pool/a"],"drop_interval_sec":90,'
          '"fall_speed":0.25}',
    );
    final rows = await fetchDisplayOverlays(db);
    expect(rows.single.configJson, contains('overlay/pool/a'));
    expect(rows.single.configJsonSchema, contains('FallingImagesOverlayConfig'));
    await db.close();
  });

  test('upsert bouncing_message stores normalized config_json with messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'bounce1',
      overlayType: kOverlayTypeBouncingMessage,
      name: 'bounce',
      configJson:
          '{"messages":["Hi there"],"color":"#ABCDEF","font_size":28,'
          '"font_weight":"700","speed":1.2}',
    );
    final rows = await fetchDisplayOverlays(db);
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
      () => upsertOverlay(
        db,
        id: 'bad_bounce',
        overlayType: kOverlayTypeBouncingMessage,
        name: 'x',
        configJson: '{"messages":["a"],"font_size":12,"nope":1}',
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

  test('upsertOverlay accepts custom overlay_type slug', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'laser_row',
      overlayType: 'laser_show',
      name: 'future',
      configJson: '{"messages":["peek"],"beam":true}',
    );
    final rows = await fetchDisplayOverlays(db);
    expect(rows.single.overlayType, 'laser_show');
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['messages'], ['peek']);
    expect(cfg['beam'], isTrue);
    await db.close();
  });

  test('overlayToJson decodes config_json', () {
    final row = DisplayOverlayRow(
      id: 'j',
      overlayType: kOverlayTypeBirthdayConfetti,
      name: 'Confetti',
      configJson: '{"shapes":["star"],"messages":["a","b"]}',
      configJsonSchema: '{"type":"object"}',
      exampleConfigJson: '{"shapes":["mix"]}',
    );
    final j = overlayToJson(row);
    expect(j['overlay_type'], kOverlayTypeBirthdayConfetti);
    expect(j['name'], 'Confetti');
    expect(j['config_json'], {
      'shapes': ['star'],
      'messages': ['a', 'b'],
    });
    expect(j['config_json_schema'], {'type': 'object'});
    expect(j['example_config_json'], {'shapes': ['mix']});
  });
}
