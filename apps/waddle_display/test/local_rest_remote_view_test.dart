import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/display_remote_view.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'helpers/memory_database.dart';
import 'helpers/rest_auth_helper.dart';

void main() {
  test('GET remote-view not configured by default', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/remote-view'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['configured'], isFalse);
    expect(body['enabled'], isFalse);
    expect(body['password_configured'], isFalse);
  });

  test('GET remote-view configured after settings PUT', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final put = await http.put(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: h.authHeaders,
      body: jsonEncode({
        'display_remote_view_enabled': true,
        'display_remote_view_host': '127.0.0.1',
        'display_remote_view_port': 6080,
        'display_remote_view_path': '/',
      }),
    );
    expect(put.statusCode, 200);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/remote-view'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['configured'], isTrue);
    expect(body['enabled'], isTrue);
    expect(body['host'], '127.0.0.1');
    expect(body['port'], 6080);
  });

  test('POST session requires configuration', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/remote-view/session'),
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
      body: jsonEncode({'display_remote_view_enabled': true}),
    );

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/remote-view/session'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['ticket'], isA<String>());
    expect(body['ticket'], isNotEmpty);
    expect(body['expires_at_ms'], isA<int>());
  });

  test('PUT and DELETE remote-view password', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final put = await http.put(
      Uri.parse('${h.baseUrl}/v1/display/remote-view/password'),
      headers: h.authHeaders,
      body: jsonEncode({'value': 'vnc-secret'}),
    );
    expect(put.statusCode, 200);

    final info = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/remote-view'),
      headers: h.authHeaders,
    );
    expect(jsonDecode(info.body)['password_configured'], isTrue);

    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/display/remote-view/password'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 200);

    final info2 = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/remote-view'),
      headers: h.authHeaders,
    );
    expect(jsonDecode(info2.body)['password_configured'], isFalse);
  });

  test('GET remote-view requires auth', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(Uri.parse('${h.baseUrl}/v1/display/remote-view'));
    expect(res.statusCode, 401);
  });
}
