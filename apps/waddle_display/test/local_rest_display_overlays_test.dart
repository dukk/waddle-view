import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';

import 'helpers/memory_database.dart';
import 'helpers/rest_auth_helper.dart';

void main() {
  test('display overlays REST CRUD', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
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
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
    );
    expect(listed.statusCode, 200);
    final decoded = jsonDecode(listed.body) as Map<String, dynamic>;
    final items = decoded['items'] as List<Object?>;
    expect(items.length, 1);

    final patch = await http.patch(
      Uri.parse('${h.baseUrl}/v1/display/overlays/x_test_overlay'),
      headers: h.authHeaders,
      body: jsonEncode({'enabled': false}),
    );
    expect(patch.statusCode, 200);
    final after = await fetchDisplayOverlaySchedules(db);
    expect(after.single.enabled, false);

    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/display/overlays/x_test_overlay'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 200);
    final empty = await fetchDisplayOverlaySchedules(db);
    expect(empty, isEmpty);
  });

  test('display overlays REST birthday confetti config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
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
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
    );
    final decoded = jsonDecode(listed.body) as Map<String, dynamic>;
    final row = (decoded['items'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['id'] == 'bd_test_overlay');
    expect(row['config_json'], isA<Map>());
  });

  test('display overlays REST rejects invalid confetti config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
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
  });

  test('display overlays REST validation and not-found', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final noId = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
      body: jsonEncode({'overlay_kind': kOverlayKindHeartsRain}),
    );
    expect(noId.statusCode, 400);

    final badJson = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
      body: '{',
    );
    expect(badJson.statusCode, 400);
    expect(badJson.body, contains('invalid_json_body'));

    final patch404 = await http.patch(
      Uri.parse('${h.baseUrl}/v1/display/overlays/ghost'),
      headers: h.authHeaders,
      body: jsonEncode({'enabled': false}),
    );
    expect(patch404.statusCode, 404);

    final del404 = await http.delete(
      Uri.parse('${h.baseUrl}/v1/display/overlays/ghost'),
      headers: h.authHeaders,
    );
    expect(del404.statusCode, 404);
  });

  test('display overlays REST bouncing_message config_json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
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
  });
}
