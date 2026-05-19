import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/microsoft_graph/microsoft_graph_oauth.dart';
import 'package:waddle_shared/config/microsoft_graph_kv.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integration_accounts/oauth_sign_in_alerts.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

AppDatabase _openMemoryDatabase() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

Future<void> _warmDatabase(AppDatabase db) async {
  await db.customStatement('select 1');
}

void main() {
  test('pollDeviceCode false completes via detached poll', () async {
    final db = _openMemoryDatabase();
    await _warmDatabase(db);
    addTearDown(db.close);
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
    final httpClient = _OAuthHttpClient(
      onSend: (request) async {
        final u = request.url;
        if (u.host == 'login.microsoftonline.com' &&
            u.path.endsWith('/devicecode')) {
          return http.Response(
            jsonEncode({
              'device_code': 'device-1',
              'user_code': 'ABCD-1234',
              'verification_uri': 'https://microsoft.com/devicelogin',
              'expires_in': 900,
            }),
            200,
          );
        }
        if (u.host == 'login.microsoftonline.com' &&
            u.path.endsWith('/token')) {
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

    final oauth = MicrosoftGraphOAuth(
      httpClient: httpClient,
      sleep: (_) async {},
    );
    final immediate = await oauth.ensureAccessToken(
      db: db,
      secrets: secrets,
      clientId: 'ms-client',
      graphAccountKey: 'work',
      pollDeviceCode: false,
    );
    expect(immediate, isNull);

    for (var i = 0; i < 50; i++) {
      final tok = await secrets.read(microsoftGraphAccessTokenSecret('work'));
      if (tok != null && tok.isNotEmpty) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(
      await secrets.read(microsoftGraphAccessTokenSecret('work')),
      'access-tok',
    );
    final alerts = await db.select(db.alerts).get();
    expect(alerts.single.dismissedAt, isNotNull);
    expect(tokenPolls, greaterThanOrEqualTo(2));
  });

  test('device code expiry dismisses alert', () async {
    final db = _openMemoryDatabase();
    await _warmDatabase(db);
    addTearDown(db.close);
    final secrets = InMemorySecretStore();
    var nowMs = 0;
    final httpClient = _OAuthHttpClient(
      onSend: (request) async {
        final u = request.url;
        if (u.path.endsWith('/devicecode')) {
          return http.Response(
            jsonEncode({
              'device_code': 'device-1',
              'user_code': 'WXYZ',
              'verification_uri': 'https://microsoft.com/devicelogin',
              'expires_in': 1,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'error': 'authorization_pending'}),
          400,
        );
      },
    );

    await db.into(db.integrationAccounts).insertOnConflictUpdate(
          IntegrationAccountsCompanion.insert(
            id: 'work',
            accountType: kIntegrationAccountTypeMicrosoftGraph,
            label: const Value('Work'),
            createdAtMs: 0,
          ),
        );

    final oauth = MicrosoftGraphOAuth(
      httpClient: httpClient,
      nowMs: () => nowMs,
      sleep: (_) async {
        nowMs += 2000;
      },
    );
    final token = await oauth.ensureAccessToken(
      db: db,
      secrets: secrets,
      clientId: 'ms-client',
      graphAccountKey: 'work',
      pollDeviceCode: true,
    );
    expect(token, isNull);
    final alert = (await db.select(db.alerts).get()).single;
    expect(alert.dismissedAt, isNotNull);
  });

  test('new device code dismisses prior alert for same account', () async {
    final db = _openMemoryDatabase();
    await _warmDatabase(db);
    addTearDown(db.close);
    final secrets = InMemorySecretStore();
    var nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.integrationAccounts).insertOnConflictUpdate(
          IntegrationAccountsCompanion.insert(
            id: 'work',
            accountType: kIntegrationAccountTypeMicrosoftGraph,
            label: const Value('Work'),
            createdAtMs: nowMs,
          ),
        );
    await db.into(db.alerts).insert(
          AlertsCompanion.insert(
            title: 'Microsoft sign-in (Work)',
            body: 'Account: Work\nCode: OLD',
            severity: const Value('auth'),
            priority: const Value(50),
            createdAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
            expiresAt: Value(
              DateTime.fromMillisecondsSinceEpoch(nowMs + 900000),
            ),
            source: const Value(kMicrosoftGraphOAuthAlertSource),
          ),
        );

    var deviceCodeCalls = 0;
    final httpClient = _OAuthHttpClient(
      onSend: (request) async {
        if (request.url.path.endsWith('/devicecode')) {
          deviceCodeCalls++;
          return http.Response(
            jsonEncode({
              'device_code': 'dc',
              'user_code': 'NEW',
              'verification_uri': 'https://microsoft.com/devicelogin',
              'expires_in': 900,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'error': 'authorization_pending'}),
          400,
        );
      },
    );

    final oauth = MicrosoftGraphOAuth(
      httpClient: httpClient,
      nowMs: () => nowMs,
      sleep: (duration) async {
        nowMs += duration.inMilliseconds;
      },
    );
    await oauth.ensureAccessToken(
      db: db,
      secrets: secrets,
      clientId: 'ms-client',
      graphAccountKey: 'work',
      pollDeviceCode: false,
    );
    // Let detached poll finish (frozen [nowMs] + no-op sleep would spin until test timeout).
    for (var i = 0; i < 50; i++) {
      final active = await activeOAuthSignInAlertsForAccount(
        db,
        accountId: 'work',
        alertSource: kMicrosoftGraphOAuthAlertSource,
        now: DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
      if (active.isNotEmpty) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(deviceCodeCalls, 1);
    final rows = await db.select(db.alerts).get();
    expect(rows.length, 2);
    expect(rows.where((r) => r.dismissedAt != null).length, 1);
    final active = await activeOAuthSignInAlertsForAccount(
      db,
      accountId: 'work',
      alertSource: kMicrosoftGraphOAuthAlertSource,
      now: DateTime.fromMillisecondsSinceEpoch(nowMs),
    );
    expect(active.length, 1);
    expect(active.single.body, contains('NEW'));
  });
}

class _OAuthHttpClient extends http.BaseClient {
  _OAuthHttpClient({required this.onSend});

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
