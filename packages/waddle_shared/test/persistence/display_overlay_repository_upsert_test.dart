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
  test('fetchDisplayOverlays returns empty list when table has no rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    addTearDown(db.close);
    expect(await fetchDisplayOverlays(db), isEmpty);
  });

  test('parseDisplayOverlayGloballyEnabled treats explicit disables', () {
    expect(parseDisplayOverlayGloballyEnabled(null), isTrue);
    expect(parseDisplayOverlayGloballyEnabled(''), isTrue);
    expect(parseDisplayOverlayGloballyEnabled('false'), isFalse);
    expect(parseDisplayOverlayGloballyEnabled('0'), isFalse);
    expect(parseDisplayOverlayGloballyEnabled('off'), isFalse);
    expect(parseDisplayOverlayGloballyEnabled('yes'), isTrue);
  });

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

  test('upsert static_image stores normalized config_json without messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'logo1',
      overlayType: kOverlayTypeStaticImage,
      label: 'Logo',
      configJson:
          '{"enabled":true,"messages":["ignored"],"image_blob_key":"$kOverlayBlobKeyDuckMascot",'
          '"x":0.9,"y":0.1,"scale":0.15,"opacity":0.5}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['image_blob_key'], kOverlayBlobKeyDuckMascot);
    expect(cfg['x'], 0.9);
    expect(cfg['opacity'], 0.5);
    expect(cfg.containsKey('messages'), isFalse);
    expect(cfg.containsKey('enabled'), isFalse);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeStaticImage),
      contains('Static image'),
    );
    await db.close();
  });

  test('upsert digital_clock stores normalized config_json without messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'dig1',
      overlayType: kOverlayTypeDigitalClock,
      label: 'Corner digital',
      configJson:
          '{"enabled":true,"messages":["ignored"],"hour24":true,"showSeconds":true,'
          '"x":0.9,"y":0.1,"scale":0.25,"opacity":0.8}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['hour24'], isTrue);
    expect(cfg['showSeconds'], isTrue);
    expect(cfg['x'], 0.9);
    expect(cfg['opacity'], 0.8);
    expect(cfg.containsKey('messages'), isFalse);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeDigitalClock),
      contains('Digital clock overlay'),
    );
    await db.close();
  });

  test('upsert photo_slideshow stores normalized config_json without messages',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'ps1',
      overlayType: kOverlayTypePhotoSlideshow,
      label: 'Corner photos',
      configJson:
          '{"enabled":true,"messages":["ignored"],"interval_sec":45,'
          '"x":0.1,"y":0.2,"scale":0.2,"category_ids":["nature"],'
          '"aspect_ratio":"landscape","min_width":800}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['interval_sec'], 45);
    expect(cfg['category_ids'], ['nature']);
    expect(cfg['aspect_ratio'], 'landscape');
    expect(cfg['min_width'], 800);
    expect(cfg.containsKey('messages'), isFalse);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypePhotoSlideshow),
      contains('Photo slideshow'),
    );
    await db.close();
  });

  test('upsert stock_quote stores normalized config_json without messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'stk1',
      overlayType: kOverlayTypeStockQuote,
      label: 'Corner AAPL',
      configJson: '{"symbolId":"aapl","x":0.1,"y":0.2,"scale":0.2}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['symbolId'], 'aapl');
    expect(cfg['x'], 0.1);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeStockQuote),
      contains('Stock quote overlay'),
    );
    await db.close();
  });

  test('upsert analog_clock stores normalized config_json without messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'ana1',
      overlayType: kOverlayTypeAnalogClock,
      label: 'Corner analog',
      configJson:
          '{"dialLabels":"roman","hourHandAccent":"accent2","x":0.1,"y":0.2,"scale":0.2}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['dialLabels'], 'roman');
    expect(cfg['hourHandAccent'], 'accent2');
    expect(cfg['x'], 0.1);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeAnalogClock),
      contains('Analog clock overlay'),
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

  test('upsert cloud_drift stores normalized config_json without messages', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    await upsertOverlay(
      db,
      id: 'cloud1',
      overlayType: kOverlayTypeCloudDrift,
      label: 'Clouds',
      configJson:
          '{"messages":["ignored"],"cloud_type":"cirrus","scatter":0.5,'
          '"density":0.4,"opacity":0.5,"color":"#C8CDD3","ignored":1}',
    );
    final rows = await fetchDisplayOverlays(db);
    final cfg = jsonDecode(rows.single.configJson) as Map<String, dynamic>;
    expect(cfg['cloud_type'], 'cirrus');
    expect(cfg['scatter'], 0.5);
    expect(cfg['density'], 0.4);
    expect(cfg['opacity'], 0.5);
    expect(cfg['color'], '#C8CDD3');
    expect(cfg.containsKey('messages'), isFalse);
    expect(cfg.containsKey('ignored'), isFalse);
    expect(
      await overlayTypeConfigJsonSchema(db, kOverlayTypeCloudDrift),
      contains('Cloud drift'),
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
      description: '',
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
