import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/adoption.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/adoption_test_helpers.dart';
import '../helpers/memory_database.dart';
import '../helpers/rest_auth_helper.dart';

void main() {
  test('adoption request and confirm returns api key', () async {
    final h = await RestTestHarness.startViaAdoption(role: kUserRoleOperator);
    addTearDown(h.dispose);

    final screens = await http.get(
      Uri.parse('${h.baseUrl}/v1/screens'),
      headers: h.authHeaders,
    );
    expect(screens.statusCode, 200);
  });

  test('confirm rejects wrong challenge', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.startViaAdoption(
      database: db,
      identifier: 'wrong-code-client',
    );
    addTearDown(h.dispose);

    final requestRes = await http.post(
      Uri.parse('${h.baseUrl}/v1/adoption/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': 'another-client',
        'role': kUserRoleViewer,
      }),
    );
    expect(requestRes.statusCode, 200);

    final confirmRes = await http.post(
      Uri.parse('${h.baseUrl}/v1/adoption/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': 'another-client',
        'challenge_code': 'BADCODE1',
      }),
    );
    expect(confirmRes.statusCode, 401);
    final body = jsonDecode(confirmRes.body) as Map<String, dynamic>;
    expect(body['error'], 'invalid_challenge');
  });

  test('adoption request creates expiring alert', () async {
    final h = await RestTestHarness.startWithApiKey(
      apiKey: 'unused-for-alert-test',
      identifier: 'alert-check',
    );
    addTearDown(h.dispose);

    final requestRes = await http.post(
      Uri.parse('${h.baseUrl}/v1/adoption/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': 'pending-client', 'role': kUserRoleAdmin}),
    );
    expect(requestRes.statusCode, 200);
    final requestBody = jsonDecode(requestRes.body) as Map<String, dynamic>;
    expect(requestBody.containsKey('challenge_code'), isFalse);
    expect(requestBody['expires_at_ms'], isA<int>());

    final rows = await h.db.select(h.db.alerts).get();
    final adoptionAlerts =
        rows.where((r) => r.source == kAdoptionAlertSource).toList();
    expect(adoptionAlerts, isNotEmpty);
    final alert = adoptionAlerts.last;
    expect(alert.expiresAt, isNotNull);
    final challenge = adoptionChallengeFromAlertBody(alert.body);
    expect(challenge.length, 8);
    expect(alert.body, contains('Admin access'));
    expect(alert.body, contains('-'));
    expect(alert.severity, 'security');
  });

  test('protected route requires api key', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(Uri.parse('${h.baseUrl}/v1/screens'));
    expect(res.statusCode, 401);
  });

  test('health remains public', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(Uri.parse('${h.baseUrl}/v1/health'));
    expect(res.statusCode, 200);
  });
}
