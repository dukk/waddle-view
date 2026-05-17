import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/api/cors_policy.dart';
import 'package:waddle_shared/config/adoption.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/adoption_test_helpers.dart';
import '../helpers/rest_auth_helper.dart';

void main() {
  group('CorsPolicy.isAdoptionOriginAllowed', () {
    late CorsPolicy policy;

    setUp(() {
      policy = CorsPolicy();
    });

    test('allows loopback and RFC1918 literals', () async {
      expect(await policy.isAdoptionOriginAllowed('http://127.0.0.1:5173'), isTrue);
      expect(await policy.isAdoptionOriginAllowed('http://192.168.1.10:8787'), isTrue);
      expect(await policy.isAdoptionOriginAllowed('http://10.0.0.5'), isTrue);
    });

    test('allows .local hostnames without DNS', () async {
      expect(await policy.isAdoptionOriginAllowed('http://waddle.local:5173'), isTrue);
    });

    test('rejects public IP literals', () async {
      expect(await policy.isAdoptionOriginAllowed('http://8.8.8.8:5173'), isFalse);
    });

    test('rejects missing or invalid origins', () async {
      expect(await policy.isAdoptionOriginAllowed(null), isFalse);
      expect(await policy.isAdoptionOriginAllowed('not-an-origin'), isFalse);
    });

    test('allows hostname when lookup resolves private only', () async {
      final privatePolicy = CorsPolicy(
        hostResolver: (_) async => [InternetAddress('192.168.2.1')],
      );
      expect(
        await privatePolicy.isAdoptionOriginAllowed('http://kiosk.lan:5173'),
        isTrue,
      );
    });

    test('denies hostname when lookup includes public address', () async {
      final mixedPolicy = CorsPolicy(
        hostResolver: (_) async => [
          InternetAddress('192.168.2.1'),
          InternetAddress('8.8.8.8'),
        ],
      );
      expect(await mixedPolicy.isAdoptionOriginAllowed('http://mixed.test'), isFalse);
    });

    test('denies hostname on lookup failure', () async {
      final failPolicy = CorsPolicy(
        hostResolver: (_) => throw const SocketException('lookup failed'),
      );
      expect(await failPolicy.isAdoptionOriginAllowed('http://offline.test'), isFalse);
    });
  });

  group('isAdoptionPath', () {
    test('matches adoption routes only', () {
      expect(isAdoptionPath('/v1/adoption/request'), isTrue);
      expect(isAdoptionPath('v1/adoption/confirm'), isTrue);
      expect(isAdoptionPath('/v1/screens'), isFalse);
    });
  });

  test('confirm adoption remembers origin for protected CORS', () async {
    const origin = 'http://192.168.50.2:5173';
    final h = await RestTestHarness.startWithApiKey(
      apiKey: 'admin-for-cors-test',
      role: kUserRoleAdmin,
    );
    addTearDown(h.dispose);

    final adoptionHeaders = {
      'Content-Type': 'application/json',
      'Origin': origin,
      'Referer': '$origin/',
    };

    final requestRes = await http.post(
      Uri.parse('${h.baseUrl}/v1/adoption/request'),
      headers: adoptionHeaders,
      body: jsonEncode({'identifier': 'cors-client', 'role': kUserRoleViewer}),
    );
    expect(requestRes.statusCode, 200);
    final requestBody = jsonDecode(requestRes.body) as Map<String, dynamic>;
    expect(requestBody.containsKey('challenge_code'), isFalse);
    final alerts = await h.db.select(h.db.alerts).get();
    final alert = alerts.lastWhere((a) => a.source == kAdoptionAlertSource);
    final challenge = adoptionChallengeFromAlertBody(alert.body);

    final confirmRes = await http.post(
      Uri.parse('${h.baseUrl}/v1/adoption/confirm'),
      headers: adoptionHeaders,
      body: jsonEncode({
        'identifier': 'cors-client',
        'challenge_code': challenge,
      }),
    );
    expect(confirmRes.statusCode, 200);

    expect(await h.corsOrigins.isOriginAllowed(origin), isTrue);

    final preflight = await http.Client().send(
      http.Request('OPTIONS', Uri.parse('${h.baseUrl}/v1/screens'))
        ..headers['Origin'] = origin,
    );
    expect(preflight.statusCode, 204);
    expect(preflight.headers['access-control-allow-origin'], origin);
  });

  test('admin bearer on request grants instantly and remembers origin', () async {
    const origin = 'http://127.0.0.1:5173';
    final h = await RestTestHarness.startWithApiKey(
      apiKey: 'admin-instant-key',
      role: kUserRoleAdmin,
    );
    addTearDown(h.dispose);

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/adoption/request'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${h.apiKey}',
        'Origin': origin,
        'Referer': '$origin/',
      },
      body: jsonEncode({
        'identifier': 'instant-client',
        'role': kUserRoleOperator,
      }),
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['api_key'], isA<String>());
    expect(body.containsKey('challenge_code'), isFalse);

    expect(await h.corsOrigins.isOriginAllowed(origin), isTrue);
  });

  test('non-admin bearer on admin request path returns 403', () async {
    final h = await RestTestHarness.startWithApiKey(
      apiKey: 'operator-key',
      role: kUserRoleOperator,
      identifier: 'operator-only',
    );
    addTearDown(h.dispose);

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/adoption/request'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${h.apiKey}',
        'Origin': 'http://127.0.0.1:5173',
      },
      body: jsonEncode({'identifier': 'x', 'role': kUserRoleViewer}),
    );
    expect(res.statusCode, 403);
  });
}
