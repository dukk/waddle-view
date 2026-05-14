import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_display/alerts/drift_alert_repository.dart';
import 'package:waddle_display/api/deployment_api_key_source.dart';
import 'package:waddle_display/api/local_rest_server.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_display/ticker/memory_ticker_curated_repository.dart';

import 'helpers/memory_database.dart';

void main() {
  test('display overlays REST CRUD', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);

    final alerts = DriftAlertRepository(db);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final keys = FakeDeploymentApiKeySource('k');
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final post = await http.post(
        Uri.parse('${server.baseUrl}/v1/display/overlays'),
        headers: {'x-api-key': 'k', 'content-type': 'application/json'},
        body: jsonEncode({
          'id': 'x_test_overlay',
          'enabled': true,
          'overlay_kind': kOverlayKindHeartsRain,
          'label': 'Test',
          'messages_json': ['Hi'],
          'repeat_annually': true,
          'start_month': 7,
          'start_day': 4,
        }),
      );
      expect(post.statusCode, 200);

      final listed = await http.get(
        Uri.parse('${server.baseUrl}/v1/display/overlays'),
        headers: {'x-api-key': 'k'},
      );
      expect(listed.statusCode, 200);
      final decoded = jsonDecode(listed.body) as Map<String, dynamic>;
      final items = decoded['items'] as List<Object?>;
      expect(items.length, 1);

      final patch = await http.patch(
        Uri.parse('${server.baseUrl}/v1/display/overlays/x_test_overlay'),
        headers: {'x-api-key': 'k', 'content-type': 'application/json'},
        body: jsonEncode({
          'enabled': false,
        }),
      );
      expect(patch.statusCode, 200);
      final after = await fetchDisplayOverlaySchedules(db);
      expect(after.single.enabled, false);

      final del = await http.delete(
        Uri.parse('${server.baseUrl}/v1/display/overlays/x_test_overlay'),
        headers: {'x-api-key': 'k'},
      );
      expect(del.statusCode, 200);
      final empty = await fetchDisplayOverlaySchedules(db);
      expect(empty, isEmpty);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('display overlays REST birthday confetti config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);

    final alerts = DriftAlertRepository(db);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final keys = FakeDeploymentApiKeySource('k');
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final post = await http.post(
        Uri.parse('${server.baseUrl}/v1/display/overlays'),
        headers: {'x-api-key': 'k', 'content-type': 'application/json'},
        body: jsonEncode({
          'id': 'bd_test_overlay',
          'enabled': true,
          'overlay_kind': kOverlayKindBirthdayConfetti,
          'label': 'Birthday',
          'messages_json': ['Happy birthday!'],
          'config_json': {
            'shapes': ['circle', 'rect'],
            'colors': ['#FF00AA'],
            'density': 0.55,
            'message_interval_sec': 33,
          },
          'repeat_annually': true,
          'start_month': 4,
          'start_day': 2,
        }),
      );
      expect(post.statusCode, 200);

      final listed = await http.get(
        Uri.parse('${server.baseUrl}/v1/display/overlays'),
        headers: {'x-api-key': 'k'},
      );
      expect(listed.statusCode, 200);
      final decoded = jsonDecode(listed.body) as Map<String, dynamic>;
      final items = decoded['items'] as List<Object?>;
      final row = items
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['id'] == 'bd_test_overlay');
      expect(row['config_json'], {
        'shapes': ['circle', 'rect'],
        'colors': ['#FF00AA'],
        'density': 0.55,
        'message_interval_sec': 33,
      });
      expect(row['config_json_schema'], isA<Map<String, dynamic>>());
      expect(row['example_config_json'], isA<Map<String, dynamic>>());
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('display overlays REST rejects invalid confetti config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);

    final alerts = DriftAlertRepository(db);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final keys = FakeDeploymentApiKeySource('k');
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final post = await http.post(
        Uri.parse('${server.baseUrl}/v1/display/overlays'),
        headers: {'x-api-key': 'k', 'content-type': 'application/json'},
        body: jsonEncode({
          'id': 'bad_confetti',
          'enabled': true,
          'overlay_kind': kOverlayKindBirthdayConfetti,
          'label': 'x',
          'messages_json': [],
          'config_json': {'shapes': ['not_a_shape']},
          'repeat_annually': true,
          'start_month': 1,
          'start_day': 2,
        }),
      );
      expect(post.statusCode, 400);
      expect(post.body, contains('invalid_config_json'));
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('display overlays REST bouncing_message config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);

    final alerts = DriftAlertRepository(db);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final keys = FakeDeploymentApiKeySource('k');
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final post = await http.post(
        Uri.parse('${server.baseUrl}/v1/display/overlays'),
        headers: {'x-api-key': 'k', 'content-type': 'application/json'},
        body: jsonEncode({
          'id': 'bounce_rest_test',
          'enabled': true,
          'overlay_kind': kOverlayKindBouncingMessage,
          'label': 'Bounce',
          'messages_json': ['Ping'],
          'config_json': {
            'color': '#00AAFF',
            'font_size': 24,
            'font_weight': 500,
            'speed': 0.8,
          },
          'repeat_annually': true,
          'start_month': 7,
          'start_day': 4,
        }),
      );
      expect(post.statusCode, 200);

      final listed = await http.get(
        Uri.parse('${server.baseUrl}/v1/display/overlays'),
        headers: {'x-api-key': 'k'},
      );
      expect(listed.statusCode, 200);
      final decoded = jsonDecode(listed.body) as Map<String, dynamic>;
      final items = decoded['items'] as List<Object?>;
      final row = items
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['id'] == 'bounce_rest_test');
      final cfg = row['config_json'] as Map<String, dynamic>;
      expect(cfg['color'], '#00AAFF');
      expect((cfg['font_size'] as num).toDouble(), closeTo(24, 0.01));
      expect(cfg['font_weight'], 500);
      expect((cfg['speed'] as num).toDouble(), closeTo(0.8, 0.001));
    } finally {
      await server.close();
      await db.close();
    }
  });
}

Future<File> _tempKeyFile(String value) async {
  final dir = await Directory.systemTemp.createTemp('wv_overlay_rest_');
  final file = File('${dir.path}/waddle_api.key');
  await file.writeAsString('$value\n', flush: true);
  return file;
}
