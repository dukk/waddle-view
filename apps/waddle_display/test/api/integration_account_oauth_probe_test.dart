import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/api/integration_account_oauth_probe.dart';
import 'package:waddle_shared/config/microsoft_graph_kv.dart'
    show
        kMicrosoftGraphOAuthAlertSource,
        kMicrosoftGraphOAuthRedirectUri,
        microsoftGraphAccessTokenSecret;
import 'package:waddle_shared/secrets/integration_secret_catalog.dart'
    show kMicrosoftGraphClientIdSecretKey;
import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/persistence/database.dart'
    show IntegrationAccountsCompanion;
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/memory_database.dart';

void main() {
  test('oauth probe returns profile when Google token is valid', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    await secrets.write('provider:client_id:google', 'google-client');
    await secrets.write(googleAccessTokenSecret('personal'), 'access-tok');
    await seedIntegrationKvForTest(
      db,
      accountId: 'personal',
      key: kIntegrationAccessTokenExpiresAtKey,
      value: '${DateTime.now().millisecondsSinceEpoch + 86400000}',
      accountType: kIntegrationAccountTypeGoogle,
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
    expect(body['oauth_sign_in_status'], 'pending');
    final alerts = await db.select(db.alerts).get();
    expect(alerts.length, 1);
    expect(alerts.single.source, kMicrosoftGraphOAuthAlertSource);
    expect(alerts.single.title, contains('Work'));
    expect(alerts.single.body, contains('Account: Work'));
    expect(alerts.single.body, contains('ABCD-1234'));
    expect(alerts.single.body, isNot(contains('Account: work')));
    await db.close();
  });

  test('oauth probe detached poll stores tokens and dismisses alert', () async {
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
    var tokenPolls = 0;
    final httpClient = _ProbeHttpClient(
      onSend: (request) async {
        final u = request.url;
        if (u.host == 'login.microsoftonline.com' && u.path.endsWith('/devicecode')) {
          return http.Response(
            jsonEncode({
              'device_code': 'device',
              'user_code': 'WXYZ-0000',
              'verification_uri': 'https://microsoft.com/devicelogin',
              'expires_in': 900,
            }),
            200,
          );
        }
        if (u.host == 'login.microsoftonline.com' && u.path.endsWith('/token')) {
          tokenPolls++;
          if (tokenPolls < 2) {
            return http.Response(
              jsonEncode({'error': 'authorization_pending'}),
              400,
            );
          }
          return http.Response(
            jsonEncode({
              'access_token': 'access-tok',
              'refresh_token': 'refresh-tok',
              'expires_in': 3600,
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
      accountId: 'work',
    );
    expect(res.statusCode, 202);

    for (var i = 0; i < 30; i++) {
      final tok = await secrets.read(microsoftGraphAccessTokenSecret('work'));
      if (tok != null && tok.isNotEmpty) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    expect(
      await secrets.read(microsoftGraphAccessTokenSecret('work')),
      'access-tok',
    );
    final alerts = await db.select(db.alerts).get();
    expect(alerts.single.dismissedAt, isNotNull);
    expect(tokenPolls, greaterThanOrEqualTo(2));
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
