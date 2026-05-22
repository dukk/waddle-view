import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'helpers/rest_auth_helper.dart';

void main() {
  test('GET live-preview not configured by default', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/live-preview'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['configured'], isFalse);
    expect(body['enabled'], isFalse);
    expect(body['fps'], 10);
    expect(body['width'], 1280);
    expect(body['capture_backend'], isA<String>());
    expect(body['capture_ready'], isTrue);
  });

  test('GET live-preview configured after settings PUT', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final put = await http.put(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: h.authHeaders,
      body: jsonEncode({
        'display_live_preview_enabled': true,
        'display_live_preview_fps': 12,
        'display_live_preview_width': 960,
        'display_live_preview_quality': 80,
      }),
    );
    expect(put.statusCode, 200);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/live-preview'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['configured'], isTrue);
    expect(body['fps'], 12);
    expect(body['width'], 960);
    expect(body['quality'], 80);
  });

  test('POST session requires configuration', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/live-preview/session'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 400);
  });

  test('POST session returns ticket when configured', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    await http.put(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: h.authHeaders,
      body: jsonEncode({'display_live_preview_enabled': true}),
    );

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/live-preview/session'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['ticket'], isA<String>());
    expect(body['ticket'], isNotEmpty);
    expect(body['expires_at_ms'], isA<int>());
  });

  test('GET live-preview requires auth', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(Uri.parse('${h.baseUrl}/v1/display/live-preview'));
    expect(res.statusCode, 401);
  });
}
