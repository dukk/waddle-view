import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_view/config/microsoft_graph_kv.dart'
    show
        kDefaultMicrosoftGraphClientId,
        kMicrosoftGraphAccessTokenExpiresAtKvKey,
        kMicrosoftGraphClientIdKvKey,
        kMicrosoftGraphOAuthAlertSource,
        kMicrosoftGraphOAuthRedirectUri,
        microsoftGraphAccessTokenSecret,
        microsoftGraphRefreshTokenSecret,
        outlookCalendarEventSource;
import 'package:waddle_view/config/provider_config_resolver.dart';
import 'package:waddle_view/data/data_write_context.dart';
import 'package:waddle_view/data/providers/microsoft_graph/microsoft_graph_oauth.dart'
    show kMicrosoftGraphOAuthScopes, MicrosoftGraphOAuth;
import 'package:waddle_view/data/providers/outlook_calendar_extra_config.dart';
import 'package:waddle_view/data/providers/outlook_calendar_data_provider.dart';
import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  test('OutlookCalendarExtraConfig defaults and parses accounts', () {
    final c = OutlookCalendarExtraConfig.parse(null);
    expect(c.accounts, isEmpty);
    expect(c.pastDays, 14);
    expect(c.futureDays, 14);

    final raw = OutlookCalendarExtraConfig.parse(
      '{"accounts":[{"graphAccountKey":"a","sources":[{"mailbox":"me","calendars":[]}]}],"pastDays":3,"futureDays":5}',
    );
    expect(raw.accounts.length, 1);
    expect(raw.accounts.first.graphAccountKey, 'a');
    expect(raw.accounts.first.sources.single.mailbox, 'me');
    expect(raw.pastDays, 3);
    expect(raw.futureDays, 5);
  });

  test('OutlookCalendarExtraConfig parses calendar objects and categoryMap', () {
    final raw = OutlookCalendarExtraConfig.parse(
      '{"accounts":[{"graphAccountKey":"x","sources":[{"mailbox":"me",'
      '"calendars":["Work",{"calendar":"Personal","categoryId":"family"}],'
      '"defaultCategoryId":"general","categoryMap":{"Client":"work"}}]}]}',
    );
    final src = raw.accounts.single.sources.single;
    expect(src.calendars.length, 2);
    expect(src.calendars[0].nameOrId, 'Work');
    expect(src.calendars[1].nameOrId, 'Personal');
    expect(src.calendars[1].categoryId, 'family');
    expect(src.defaultCategoryId, 'general');
    expect(src.categoryMap['Client'], 'work');
  });

  test('empty accounts performs no HTTP', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedKvAndProvider(db, extraAccountsJson: '[]');
    final http = _CountingClient();
    final ctx = _ctx(db, InMemorySecretStore());
    final p = OutlookCalendarDataProvider(httpClient: http);
    await p.collect(ctx);
    expect(http.requests, 0);
    await db.close();
  });

  test('poll gate skips second collect within pollSeconds', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedKvAndProvider(
      db,
      pollSeconds: 3600,
      extraAccountsJson:
          '[{"graphAccountKey":"u","sources":[{"mailbox":"me","calendars":[]}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    var clock = 10_000_000_000;
    final http = _CountingClient();
    final ctx = _ctx(db, secrets);
    final p = OutlookCalendarDataProvider(httpClient: http, nowMs: () => clock);
    await p.collect(ctx);
    expect(http.requests, greaterThan(0));
    final n1 = http.requests;
    clock += 1000;
    await p.collect(ctx);
    expect(http.requests, n1);
    clock = 10_000_000_000 + (3600 * 1000) + 1;
    await p.collect(ctx);
    expect(http.requests, greaterThan(n1));
    await db.close();
  });

  test('refresh path updates access token without device code', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedKvAndProvider(
      db,
      pollSeconds: 0,
      extraAccountsJson:
          '[{"graphAccountKey":"u","sources":[{"mailbox":"me","calendars":[]}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphRefreshTokenSecret('u'), 'my_refresh');
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'old');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '1',
          ),
        );
    final http = _RefreshThenGraphClient();
    final ctx = _ctx(db, secrets);
    final p = OutlookCalendarDataProvider(httpClient: http);
    await p.collect(ctx);
    expect(http.deviceCodePosts, 0);
    expect(http.refreshTokenRequestBody, isNotNull);
    expect(
      http.refreshTokenRequestBody,
      contains(
        'redirect_uri=${Uri.encodeQueryComponent(kMicrosoftGraphOAuthRedirectUri)}',
      ),
    );
    expect(http.refreshTokenRequestBody, contains('grant_type=refresh_token'));
    expect(await secrets.read(microsoftGraphAccessTokenSecret('u')), 'access_refreshed');
    final rows = await db.select(db.calendarEvents).get();
    expect(rows.length, 1);
    expect(rows.single.externalId, 'evt1');
    expect(rows.single.source, outlookCalendarEventSource('u'));
    expect(rows.single.icalUid, '040000008200E00074C5B7101A82E008');
    await db.close();
  });

  test('device code flow inserts alert and stores calendar events', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedKvAndProvider(
      db,
      pollSeconds: 0,
      extraAccountsJson:
          '[{"graphAccountKey":"u","sources":[{"mailbox":"me","calendars":[]}]}]',
    );
    final secrets = InMemorySecretStore();
    final http = _DeviceThenGraphClient();
    var clock = 0;
    final oauth = MicrosoftGraphOAuth(
      httpClient: http,
      nowMs: () => clock,
      sleep: (_) async {
        clock += 5000;
      },
    );
    final ctx = _ctx(db, secrets);
    final p = OutlookCalendarDataProvider(httpClient: http, oauth: oauth);
    await p.collect(ctx);
    final alerts = await db.select(db.dashboardAlerts).get();
    expect(alerts.length, 1);
    expect(alerts.single.source, kMicrosoftGraphOAuthAlertSource);
    expect(alerts.single.severity, 'auth');
    expect(alerts.single.body, contains('ABCD-EFGH'));
    expect(alerts.single.title, contains('u'));
    expect(
      alerts.single.qrPayload,
      'https://microsoft.com/devicelogin?user_code=ABCD-EFGH',
    );
    expect(http.deviceCodeRequestBody, isNotNull);
    expect(
      http.deviceCodeRequestBody,
      contains(
        'redirect_uri=${Uri.encodeQueryComponent(kMicrosoftGraphOAuthRedirectUri)}',
      ),
    );
    expect(
      http.deviceCodeRequestBody,
      contains(Uri.encodeQueryComponent(kMicrosoftGraphOAuthScopes)),
    );
    expect(http.deviceCodeTokenBodies.length, greaterThanOrEqualTo(1));
    expect(
      http.deviceCodeTokenBodies.first,
      contains(
        'redirect_uri=${Uri.encodeQueryComponent(kMicrosoftGraphOAuthRedirectUri)}',
      ),
    );
    expect(alerts.single.dismissedAt, isNotNull);
    final rows = await db.select(db.calendarEvents).get();
    expect(rows.length, 1);
    expect(rows.single.externalId, 'evt1');
    await db.close();
  });
}

DataWriteContext _ctx(AppDatabase db, InMemorySecretStore secrets) {
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: FakeBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

Future<void> _seedKvAndProvider(
  AppDatabase db, {
  required String extraAccountsJson,
  int pollSeconds = 0,
}) async {
  await db.into(db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: kMicrosoftGraphClientIdKvKey,
          value: kDefaultMicrosoftGraphClientId,
        ),
      );
  await db.into(db.providerSettings).insertOnConflictUpdate(
        ProviderSettingsCompanion.insert(
          id: kOutlookCalendarProviderId,
          providerType: 'outlook_calendar',
          enabled: const Value(true),
          pollSeconds: Value(pollSeconds),
          baseUrl: const Value('https://graph.microsoft.com/v1.0'),
          configJson: Value(
            '{"accounts":$extraAccountsJson,"pastDays":14,"futureDays":14}',
          ),
        ),
      );
}

class _CountingClient extends http.BaseClient {
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'value': []}))),
      200,
      headers: {'Content-Type': 'application/json'},
    );
  }
}

class _RefreshThenGraphClient extends http.BaseClient {
  int deviceCodePosts = 0;
  String? refreshTokenRequestBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.host == 'login.microsoftonline.com' && u.path.endsWith('/devicecode')) {
      deviceCodePosts++;
    }
    if (u.host == 'login.microsoftonline.com' && u.path.endsWith('/token')) {
      final req = request as http.Request;
      if (req.body.contains('grant_type=refresh_token')) {
        refreshTokenRequestBody = req.body;
        return _json({
          'access_token': 'access_refreshed',
          'refresh_token': 'r2',
          'expires_in': 3600,
        });
      }
    }
    if (u.host == 'graph.microsoft.com') {
      return _json({
        'value': [
          {
            'id': 'evt1',
            'subject': 'Hello',
            'isAllDay': false,
            'iCalUId': '040000008200E00074C5B7101A82E008',
            'start': {
              'dateTime': '2026-06-01T10:00:00.0000000',
              'timeZone': 'UTC',
            },
            'end': {
              'dateTime': '2026-06-01T11:00:00.0000000',
              'timeZone': 'UTC',
            },
          },
        ],
      });
    }
    return http.StreamedResponse(Stream.value(utf8.encode('')), 404);
  }

  http.StreamedResponse _json(Object obj) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(obj))),
        200,
        headers: {'Content-Type': 'application/json'},
      );
}

class _DeviceThenGraphClient extends http.BaseClient {
  int _tokenPosts = 0;
  String? deviceCodeRequestBody;
  final List<String> deviceCodeTokenBodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.host == 'login.microsoftonline.com' && u.path.endsWith('/devicecode')) {
      deviceCodeRequestBody = (request as http.Request).body;
      return _json({
        'user_code': 'ABCD-EFGH',
        'device_code': 'dc',
        'verification_uri': 'https://microsoft.com/devicelogin',
        'verification_uri_complete':
            'https://microsoft.com/devicelogin?user_code=ABCD-EFGH',
        'expires_in': 900,
        'interval': 0,
      });
    }
    if (u.host == 'login.microsoftonline.com' && u.path.endsWith('/token')) {
      deviceCodeTokenBodies.add((request as http.Request).body);
      _tokenPosts++;
      if (_tokenPosts == 1) {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(jsonEncode({'error': 'authorization_pending'})),
          ),
          400,
          headers: {'Content-Type': 'application/json'},
        );
      }
      return _json({
        'access_token': 'tok_new',
        'refresh_token': 'ref_new',
        'expires_in': 3600,
      });
    }
    if (u.host == 'graph.microsoft.com') {
      return _json({
        'value': [
          {
            'id': 'evt1',
            'subject': 'Hello',
            'isAllDay': false,
            'iCalUId': '040000008200E00074C5B7101A82E008',
            'start': {
              'dateTime': '2026-06-01T10:00:00.0000000',
              'timeZone': 'UTC',
            },
            'end': {
              'dateTime': '2026-06-01T11:00:00.0000000',
              'timeZone': 'UTC',
            },
          },
        ],
      });
    }
    return http.StreamedResponse(Stream.value(utf8.encode('')), 404);
  }

  http.StreamedResponse _json(Object obj) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(obj))),
        200,
        headers: {'Content-Type': 'application/json'},
      );
}
