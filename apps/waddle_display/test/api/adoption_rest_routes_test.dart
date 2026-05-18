import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/adoption.dart';
import 'package:waddle_shared/config/adoption_allowed_roles.dart';
import 'package:waddle_shared/persistence/database.dart';

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

  test('adoption clients list revoke and grant', () async {
    final h = await RestTestHarness.startViaAdoption(role: kUserRoleAdmin);
    addTearDown(h.dispose);

    final listRes = await http.get(
      Uri.parse('${h.baseUrl}/v1/adoption/clients'),
      headers: h.authHeaders,
    );
    expect(listRes.statusCode, 200);
    final listed = jsonDecode(listRes.body) as Map<String, dynamic>;
    final items = listed['items'] as List<dynamic>;
    expect(items, isNotEmpty);
    final self = items.firstWhere(
      (e) => (e as Map<String, dynamic>)['identifier'] == h.identifier,
    ) as Map<String, dynamic>;
    expect(self['masked_api_key'], startsWith('wd_'));
    expect(self['role'], kUserRoleAdmin);

    final grantRes = await http.post(
      Uri.parse('${h.baseUrl}/v1/adoption/clients'),
      headers: {
        ...h.authHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'identifier': 'issued-from-settings',
        'role': kUserRoleViewer,
      }),
    );
    expect(grantRes.statusCode, 200);
    final granted = jsonDecode(grantRes.body) as Map<String, dynamic>;
    expect(granted['api_key'], startsWith('wd_'));

    final sessionRes = await http.get(
      Uri.parse('${h.baseUrl}/v1/adoption/session'),
      headers: {
        'Authorization': 'Bearer ${granted['api_key']}',
      },
    );
    expect(sessionRes.statusCode, 200);
    final session = jsonDecode(sessionRes.body) as Map<String, dynamic>;
    expect(session['identifier'], 'issued-from-settings');
    expect(session['role'], kUserRoleViewer);

    final afterGrant = await http.get(
      Uri.parse('${h.baseUrl}/v1/adoption/clients'),
      headers: h.authHeaders,
    );
    final afterItems =
        (jsonDecode(afterGrant.body) as Map<String, dynamic>)['items'] as List;
    final issued = afterItems.firstWhere(
      (e) => (e as Map<String, dynamic>)['identifier'] == 'issued-from-settings',
    ) as Map<String, dynamic>;

    final revokeRes = await http.delete(
      Uri.parse('${h.baseUrl}/v1/adoption/clients/${issued['id']}'),
      headers: h.authHeaders,
    );
    expect(revokeRes.statusCode, 200);
  });

  test('adoption clients require admin', () async {
    final h = await RestTestHarness.startViaAdoption(role: kUserRoleOperator);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/adoption/clients'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 403);
  });

  test('adoption request rejected when new requests disabled', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: kAdoptionAllowNewRequestsKvKey,
            value: 'false',
          ),
        );
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/adoption/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': 'blocked-client', 'role': kUserRoleViewer}),
    );
    expect(res.statusCode, 403);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['error'], 'adoption_role_not_allowed');
  });

  test('adoption request allowed only for configured roles', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: kAdoptionAllowedRolesKvKey,
            value: encodeAdoptionAllowedRoles({kUserRoleViewer}),
          ),
        );
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final blocked = await http.post(
      Uri.parse('${h.baseUrl}/v1/adoption/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': 'admin-client', 'role': kUserRoleAdmin}),
    );
    expect(blocked.statusCode, 403);
    expect(
      (jsonDecode(blocked.body) as Map<String, dynamic>)['error'],
      'adoption_role_not_allowed',
    );

    final allowed = await http.post(
      Uri.parse('${h.baseUrl}/v1/adoption/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': 'viewer-client', 'role': kUserRoleViewer}),
    );
    expect(allowed.statusCode, 200);
  });
}
