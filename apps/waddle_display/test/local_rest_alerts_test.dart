import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/rest_auth_helper.dart';

void main() {
  test('POST and DELETE alerts', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/alerts'),
      headers: h.authHeaders,
      body: '{"title":"a","body":"b","priority":2}',
    );
    expect(post.statusCode, 200);
    final id = (jsonDecode(post.body) as Map<String, dynamic>)['id'] as int;
    final list = await http.get(
      Uri.parse('${h.baseUrl}/v1/alerts'),
      headers: h.authHeaders,
    );
    expect(list.statusCode, 200);
    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/alerts/$id'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 200);
  });

  test('POST alerts accepts loose optional fields', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/alerts'),
      headers: h.authHeaders,
      body: jsonEncode({
        'title': 't',
        'body': 'b',
        'qr_payload': 'https://example.com',
        'expires_at': 9999999999999,
      }),
    );
    expect(post.statusCode, 200);
  });
}
