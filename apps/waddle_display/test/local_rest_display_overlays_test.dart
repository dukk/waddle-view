import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/display_overlay_repository.dart';

import 'helpers/memory_database.dart';
import 'helpers/rest_auth_helper.dart';

void main() {
  test('display overlays REST CRUD', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'x_test_overlay',
        'overlay_type': kOverlayTypeHeartsRain,
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
      body: jsonEncode({'label': 'Updated'}),
    );
    expect(patch.statusCode, 200);
    final after = await fetchDisplayOverlaySchedules(db);
    expect(after.single.label, 'Updated');

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
    await ensureOverlaysTableExists(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'bd_test_overlay',
        'overlay_type': kOverlayTypeBirthdayConfetti,
        'label': 'Birthday',
        'config_json': {
          'messages': ['Happy birthday!'],
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
    await ensureOverlaysTableExists(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'bad_confetti',
        'overlay_type': kOverlayTypeBirthdayConfetti,
        'label': 'x',
        'config_json': {'messages': [], 'shapes': ['not_a_shape']},
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
    await ensureOverlaysTableExists(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final noId = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
      body: jsonEncode({'overlay_type': kOverlayTypeHeartsRain}),
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
      body: jsonEncode({'label': 'ghost'}),
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
    await ensureOverlaysTableExists(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'bounce_rest_test',
        'overlay_type': kOverlayTypeBouncingMessage,
        'label': 'Bounce',
        'config_json': {
          'messages': ['Ping'],
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

  test('display overlays REST uploads image blob', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureOverlaysTableExists(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    const pngB64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final upload = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays/blobs'),
      headers: h.authHeaders,
      body: jsonEncode({
        'bytes_base64': pngB64,
        'content_type': 'image/png',
      }),
    );
    expect(upload.statusCode, 200, reason: upload.body);
    final decoded = jsonDecode(upload.body) as Map<String, dynamic>;
    final blobKey = decoded['blob_key'] as String;
    expect(blobKey, startsWith('overlay/pool/'));

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/overlays'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'fall_rest_test',
        'overlay_type': kOverlayTypeFallingImages,
        'label': 'Falling',
        'config_json': {
          'image_blob_keys': [blobKey],
          'drop_interval_sec': 45,
          'fall_speed': 0.12,
        },
        'repeat_annually': true,
        'start_month': 7,
        'start_day': 4,
      }),
    );
    expect(post.statusCode, 200);
  });
}
