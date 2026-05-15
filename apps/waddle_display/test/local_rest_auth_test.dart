import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/tables.dart';

import 'helpers/rest_auth_helper.dart';

void main() {
  test('bootstrap display login warns and disables after named user', () async {
    final h = await BootstrapRestTestHarness.start();
    addTearDown(h.dispose);
    final login = jsonDecode(
      (await http.post(
        Uri.parse('${h.baseUrl}/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': kBootstrapUsername,
          'password': h.instanceId,
        }),
      )).body,
    ) as Map<String, dynamic>;
    expect(login['warnings'], contains('bootstrap_admin'));

    final createRes = await http.post(
      Uri.parse('${h.baseUrl}/v1/users'),
      headers: {
        ...h.authHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': 'operator1',
        'password': 'operator-pass-12',
        'role': kUserRoleOperator,
      }),
    );
    expect(createRes.statusCode, 200);

    final bootstrapLogin = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': kBootstrapUsername,
        'password': h.instanceId,
      }),
    );
    expect(bootstrapLogin.statusCode, 403);
    expect(bootstrapLogin.body, contains('bootstrap_admin_disabled'));
  });

  test('viewer cannot POST alerts', () async {
    final h = await RestTestHarness.start(role: kUserRoleViewer);
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/alerts'),
      headers: h.authHeaders,
      body: jsonEncode({'title': 't', 'body': 'b'}),
    );
    expect(res.statusCode, 403);
  });

  test('unauthenticated GET providers returns 401', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.get(Uri.parse('${h.baseUrl}/v1/providers'));
    expect(res.statusCode, 401);
  });

  test('/admin returns 410', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.get(Uri.parse('${h.baseUrl}/admin/login'));
    expect(res.statusCode, 410);
  });
}
