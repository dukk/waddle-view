import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_falling_images_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/display_overlay_row.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/tables/overlay_types_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('watchDisplayOverlaySchedules emits when overlay row changes', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    addTearDown(db.close);

    final events = <List<DisplayOverlayRow>>[];
    final sub = watchDisplayOverlaySchedules(db).listen(events.add);
    addTearDown(sub.cancel);

    await Future<void>.delayed(Duration.zero);
    expect(events, isNotEmpty);

    await upsertOverlay(
      db,
      id: 'watch_me',
      overlayType: kOverlayTypeBouncingMessage,
      label: 'bounce',
      configJson: '{"messages":["A"],"font_size":38}',
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.length, greaterThanOrEqualTo(2));
    expect(
      events.last.firstWhere((r) => r.id == 'watch_me').configJson,
      contains('"font_size":38'),
    );

    await upsertOverlay(
      db,
      id: 'watch_me',
      overlayType: kOverlayTypeBouncingMessage,
      label: 'bounce',
      configJson: '{"messages":["A"],"font_size":48}',
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.length, greaterThanOrEqualTo(3));
    expect(
      events.last.firstWhere((r) => r.id == 'watch_me').configJson,
      contains('"font_size":48'),
    );
  });

  test('upsert shape_rain stores shapes without messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'h1',
      overlayType: kOverlayTypeShapeRain,
      label: 'Raining Hearts',
      configJson:
          '{"messages":["x"],"shapes":["heart","dog"],"ignored":1}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['shapes'], ['heart', 'dog']);
    expect(cfg.containsKey('messages'), isFalse);
    expect(cfg.containsKey('ignored'), isFalse);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeShapeRain),
      contains('Shape rain'),
    );
    await db.close();
  });

  test('upsert birthday_confetti stores normalized config_json without messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'b1',
      overlayType: kOverlayTypeBirthdayConfetti,
      label: 'birthday',
      configJson:
          '{"messages":["Party"],"shapes":["rect"],"colors":["#ABCDEF"],'
          '"density":0.2,"message_interval_sec":15}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg.containsKey('shapes'), isFalse);
    expect(cfg['colors'], ['#ABCDEF']);
    expect(cfg.containsKey('messages'), isFalse);
    expect(cfg.containsKey('message_interval_sec'), isFalse);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeBirthdayConfetti),
      contains('Birthday confetti'),
    );
    await db.close();
  });

  test('upsert falling_images stores normalized config_json without messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'fall1',
      overlayType: kOverlayTypeFallingImages,
      label: 'drops',
      configJson:
          '{"messages":["Party"],"image_blob_keys":["overlay/pool/a"],'
          '"drop_interval_sec":90,"fall_speed":0.25,"image_scale":0.1}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['image_blob_keys'], ['overlay/pool/a']);
    expect(cfg['fall_speed'], closeTo(0.25 * kFallingImagesLegacyFallSpeedRefHeightPx, 0.01));
    expect(cfg.containsKey('messages'), isFalse);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeFallingImages),
      contains('Falling images'),
    );
    await db.close();
  });

  test('upsert floating_balloons stores normalized config_json without messages',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'balloons1',
      overlayType: kOverlayTypeFloatingBalloons,
      label: 'balloons',
      configJson:
          '{"messages":["Party"],"colors":["#AABBCC","#112233"],'
          '"spawn_interval_sec":30,"rise_speed":100,"max_active":5,'
          '"cluster_chance":0.5,"balloon_scale":0.1,"scale_jitter":0.2,'
          '"opacity":0.8}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['colors'], ['#AABBCC', '#112233']);
    expect(cfg['spawn_interval_sec'], 30);
    expect(cfg.containsKey('messages'), isFalse);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeFloatingBalloons),
      contains('Floating balloons'),
    );
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
      label: 'bounce',
      configJson:
          '{"messages":["Hi there"],"color":"#ABCDEF","font_size":28,'
          '"font_weight":"700","speed":1.2}',
    );
    final rows = await fetchDisplayOverlays(db);
    expect(rows.single.configJson, contains('#ABCDEF'));
    expect(rows.single.configJson, contains('"Hi there"'));
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeBouncingMessage),
      contains('BouncingMessageOverlayConfig'),
    );
    await db.close();
  });

  test('upsert edge_glow stores normalized config_json without messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'edge1',
      overlayType: kOverlayTypeEdgeGlow,
      label: 'Alarm glow',
      configJson:
          '{"messages":["ignored"],"color":"#FF3B30","intensity":0.7,"pulse_speed":1.2,"ignored":1}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['color'], '#FF3B30');
    expect(cfg['intensity'], 0.7);
    expect(cfg['pulse_speed'], 1.2);
    expect(cfg.containsKey('messages'), isFalse);
    expect(cfg.containsKey('ignored'), isFalse);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeEdgeGlow),
      contains('Edge glow'),
    );
    await db.close();
  });

  test('upsert matrix_rain stores normalized config_json without messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'matrix1',
      overlayType: kOverlayTypeMatrixRain,
      label: 'Matrix',
      configJson:
          '{"messages":["ignored"],"opacity":0.5,"fall_speed":0.8,"ignored":1}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['opacity'], 0.5);
    expect(cfg['fall_speed'], 0.8);
    expect(cfg.containsKey('messages'), isFalse);
    expect(cfg.containsKey('ignored'), isFalse);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeMatrixRain),
      contains('Matrix rain'),
    );
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
        label: 'x',
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
      label: 'future',
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
      label: 'Confetti',
      configJson: '{"fall_speed":0.2,"opacity":0.5}',
    );
    final jDefault = overlayToJson(row);
    expect(jDefault.containsKey('config_json_schema'), isFalse);

    final j = overlayToJson(
      row,
      includeConfigDocs: true,
      configJsonSchema: '{"type":"object"}',
    );
    expect(j['overlay_type'], kOverlayTypeBirthdayConfetti);
    expect(j['label'], 'Confetti');
    expect(j['config_json'], {
      'fall_speed': 0.2,
      'opacity': 0.5,
    });
    expect(j['config_json_schema'], {'type': 'object'});
  });
}
