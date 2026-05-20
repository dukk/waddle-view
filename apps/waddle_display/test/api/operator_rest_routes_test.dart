import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/rest_auth_helper.dart';

void main() {
  test('GET display settings requires auth', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
    );
    expect(res.statusCode, 401);
  });

  test('GET meta config-schemas returns documented keys', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/meta/config-schemas'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body.containsKey('kv_widget_types'), isTrue);
    expect(body.containsKey('overlay_types'), isTrue);

    final overlayTypes = body['overlay_types'] as List<dynamic>;
    final slugs = overlayTypes
        .map((e) => (e as Map<String, dynamic>)['overlay_type'] as String)
        .toSet();
    expect(slugs, containsAll(['static_image', 'digital_clock', 'analog_clock']));
  });

  test('GET telemetry programs returns items list', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/telemetry/programs'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['items'], isA<List>());
  });
}
