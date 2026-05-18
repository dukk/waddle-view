import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/api/integration_account_oauth_probe.dart';
import 'package:waddle_display/config/microsoft_graph_kv.dart'
    show kMicrosoftGraphOAuthAlertSource, kMicrosoftGraphOAuthRedirectUri;
import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/database.dart'
    show ConfigKeyValuesCompanion, IntegrationAccountsCompanion;
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

import '../helpers/memory_database.dart';

void main() {
  test('oauth probe returns profile when Google token is valid', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    await secrets.write('provider:client_id:google', 'google-client');
    await secrets.write(googleAccessTokenSecret('personal'), 'access-tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kGoogleAccessTokenExpiresAtKvKey('personal'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000}',
          ),
        );
    await db.into(db.integrationAccounts).insertOnConflictUpdate(
          IntegrationAccountsCompanion.insert(
            id: 'personal',
            accountType: kIntegrationAccountTypeGoogle,
            label: const Value('Personal'),
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    final httpClient = _ProbeHttpClient(
      onSend: (request) async {
        if (request.url.host == 'www.googleapis.com') {
          return http.Response(
            jsonEncode({
              'sub': 'sub-1',
              'name': 'Pat',
              'email': 'pat@example.com',
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      },
    );
    final res = await handleIntegrationAccountOAuthProbe(
      db: db,
      secrets: secrets,
      httpClient: httpClient,
      accountId: 'personal',
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['configured'], isTrue);
    expect(body['profile'], isA<Map<String, dynamic>>());
    expect(body['profile']['display_name'], 'Pat');
    await db.close();
  });

  test('oauth probe starts Microsoft device-code alert and returns 202', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    await secrets.write(kMicrosoftGraphClientIdSecretKey, 'ms-client');
    await db.into(db.integrationAccounts).insertOnConflictUpdate(
          IntegrationAccountsCompanion.insert(
            id: 'work',
            accountType: kIntegrationAccountTypeMicrosoftGraph,
            label: const Value('Work'),
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    final httpClient = _ProbeHttpClient(
      onSend: (request) async {
        final u = request.url;
        if (u.host == 'login.microsoftonline.com' && u.path.endsWith('/devicecode')) {
          final req = request as http.Request;
          expect(
            req.body,
            contains(
              'redirect_uri=${Uri.encodeQueryComponent(kMicrosoftGraphOAuthRedirectUri)}',
            ),
          );
          return http.Response(
            jsonEncode({
              'device_code': 'device',
              'user_code': 'ABCD-1234',
              'verification_uri': 'https://microsoft.com/devicelogin',
              'verification_uri_complete':
                  'https://microsoft.com/devicelogin?user_code=ABCD-1234',
              'expires_in': 900,
            }),
            200,
          );
        }
        if (u.host == 'login.microsoftonline.com' && u.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({'error': 'authorization_pending'}),
            400,
          );
        }
        return http.Response('{}', 404);
      },
    );
    final res = await handleIntegrationAccountOAuthProbe(
      db: db,
      secrets: secrets,
      httpClient: httpClient,
      accountId: 'work',
    );
    expect(res.statusCode, 202);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['status'], 'sign_in_required');
    expect(body['sign_in_alert_active'], isTrue);
    final alerts = await db.select(db.alerts).get();
    expect(alerts.length, 1);
    expect(alerts.single.source, kMicrosoftGraphOAuthAlertSource);
    expect(alerts.single.body, contains('ABCD-1234'));
    await db.close();
  });
}

class _ProbeHttpClient extends http.BaseClient {
  _ProbeHttpClient({required this.onSend});

  final Future<http.Response> Function(http.BaseRequest request) onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await onSend(request);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
      reasonPhrase: res.reasonPhrase,
    );
  }
}
