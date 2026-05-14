import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/config/google_kv.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_display/data/data_write_context.dart';
import 'package:waddle_display/data/providers/google_calendar/google_calendar_data_provider.dart';
import 'package:waddle_display/data/providers/google_calendar/google_calendar_extra_config.dart';
import 'package:waddle_display/data/providers/google_calendar/google_oauth.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  test('GoogleCalendarExtraConfig defaults and parses accounts', () {
    final c = GoogleCalendarExtraConfig.parse(null);
    expect(c.accounts, isEmpty);
    expect(c.pastDays, 14);
    expect(c.futureDays, 14);

    final raw = GoogleCalendarExtraConfig.parse(
      '{"accounts":[{"googleAccountKey":"a","sources":[{"calendars":["primary"]}]}],"pastDays":2,"futureDays":6}',
    );
    expect(raw.accounts.length, 1);
    expect(raw.accounts.first.googleAccountKey, 'a');
    expect(
      raw.accounts.first.sources.single.calendars.single.nameOrId,
      'primary',
    );
    expect(raw.pastDays, 2);
    expect(raw.futureDays, 6);
  });

  test('GoogleCalendarExtraConfig parses calendar category aliases', () {
    final raw = GoogleCalendarExtraConfig.parse(
      '{"accounts":[{"googleAccountKey":"u","sources":[{"defaultCategory":"general","calendars":[{"calendar":"primary","category":"family"}]}]}]}',
    );
    final source = raw.accounts.single.sources.single;
    expect(source.defaultCategoryId, 'general');
    expect(source.calendars.single.nameOrId, 'primary');
    expect(source.calendars.single.categoryId, 'family');
  });

  test('empty accounts performs no HTTP', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedKvAndProvider(db, extraAccountsJson: '[]');
    final http = _CountingClient();
    final p = GoogleCalendarDataProvider(httpClient: http);
    await p.collect(_ctx(db, InMemorySecretStore()));
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
          '[{"googleAccountKey":"u","sources":[{"calendars":["primary"]}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(googleAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kGoogleAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    var clock = 10_000_000_000;
    final http = _CountingClient();
    final p = GoogleCalendarDataProvider(httpClient: http, nowMs: () => clock);
    await p.collect(_ctx(db, secrets));
    expect(http.requests, greaterThan(0));
    final n1 = http.requests;
    clock += 1000;
    await p.collect(_ctx(db, secrets));
    expect(http.requests, n1);
    clock = 10_000_000_000 + (3600 * 1000) + 1;
    await p.collect(_ctx(db, secrets));
    expect(http.requests, greaterThan(n1));
    await db.close();
  });

  test('refresh path updates access token without device code', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, const ['family']);
    await _seedKvAndProvider(
      db,
      extraAccountsJson:
          '[{"googleAccountKey":"u","sources":[{"calendars":[{"calendar":"primary","category":"family"}]}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(googleRefreshTokenSecret('u'), 'my_refresh');
    await secrets.write(googleAccessTokenSecret('u'), 'old');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kGoogleAccessTokenExpiresAtKvKey('u'),
            value: '1',
          ),
        );
    final http = _RefreshThenGoogleClient();
    final p = GoogleCalendarDataProvider(httpClient: http);
    await p.collect(_ctx(db, secrets));
    expect(http.deviceCodePosts, 0);
    expect(http.refreshTokenRequestBody, isNotNull);
    expect(http.refreshTokenRequestBody, contains('grant_type=refresh_token'));
    expect(await secrets.read(googleAccessTokenSecret('u')), 'access_refreshed');
    final rows = await db.select(db.calendarEvents).get();
    expect(rows.length, 1);
    expect(rows.single.externalId, 'evt1');
    expect(rows.single.source, googleCalendarEventSource('u'));
    expect(rows.single.icalUid, 'google-ical-1');
    expect(rows.single.categoryId, 'family');
    await db.close();
  });

  test('device code flow inserts alert and stores calendar events', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedKvAndProvider(
      db,
      extraAccountsJson:
          '[{"googleAccountKey":"u","sources":[{"calendars":["primary"]}]}]',
    );
    final secrets = InMemorySecretStore();
    final http = _DeviceThenGoogleClient();
    var clock = 0;
    final oauth = GoogleOAuth(
      httpClient: http,
      nowMs: () => clock,
      sleep: (_) async {
        clock += 5000;
      },
    );
    final p = GoogleCalendarDataProvider(httpClient: http, oauth: oauth);
    await p.collect(_ctx(db, secrets));
    final alerts = await db.select(db.dashboardAlerts).get();
    expect(alerts.length, 1);
    expect(alerts.single.source, kGoogleOAuthAlertSource);
    expect(alerts.single.severity, 'auth');
    expect(alerts.single.body, contains('ABCD-EFGH'));
    expect(alerts.single.title, contains('u'));
    expect(http.deviceCodeRequestBody, isNotNull);
    expect(
      http.deviceCodeRequestBody,
      contains(Uri.encodeQueryComponent(kGoogleCalendarOAuthScopes)),
    );
    expect(http.deviceCodeTokenBodies.length, greaterThanOrEqualTo(1));
    expect(alerts.single.dismissedAt, isNotNull);
    final rows = await db.select(db.calendarEvents).get();
    expect(rows.length, 1);
    expect(rows.single.externalId, 'evt1');
    await db.close();
  });
}

DataWriteContext _ctx(AppDatabase db, InMemorySecretStore secrets) {
  final resolver = ProviderConfigResolver(db, {});
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
          key: kGoogleClientIdKvKey,
          value: 'google-client-id',
        ),
      );
  await db.into(db.providerSettings).insertOnConflictUpdate(
        ProviderSettingsCompanion.insert(
          id: kGoogleCalendarProviderId,
          providerType: 'google_calendar',
          enabled: const Value(true),
          pollSeconds: Value(pollSeconds),
          baseUrl: const Value(kDefaultGoogleCalendarBaseUrl),
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
      Stream.value(utf8.encode(jsonEncode({'items': []}))),
      200,
      headers: {'Content-Type': 'application/json'},
    );
  }
}

class _RefreshThenGoogleClient extends http.BaseClient {
  int deviceCodePosts = 0;
  String? refreshTokenRequestBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.host == 'oauth2.googleapis.com' && u.path.endsWith('/device/code')) {
      deviceCodePosts++;
    }
    if (u.host == 'oauth2.googleapis.com' && u.path.endsWith('/token')) {
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
    if (u.host == 'www.googleapis.com' && u.path.endsWith('/calendarList')) {
      return _json({
        'items': [
          {'id': 'primary', 'summary': 'Primary'}
        ],
      });
    }
    if (u.host == 'www.googleapis.com' && u.path.contains('/events')) {
      return _json({
        'items': [
          {
            'id': 'evt1',
            'summary': 'Hello',
            'iCalUID': 'google-ical-1',
            'start': {'dateTime': '2026-06-01T10:00:00.0000000Z'},
            'end': {'dateTime': '2026-06-01T11:00:00.0000000Z'},
          },
        ],
      });
    }
    return http.StreamedResponse(Stream.value(utf8.encode('')), 404);
  }
}

class _DeviceThenGoogleClient extends http.BaseClient {
  int _tokenPosts = 0;
  String? deviceCodeRequestBody;
  final List<String> deviceCodeTokenBodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.host == 'oauth2.googleapis.com' && u.path.endsWith('/device/code')) {
      deviceCodeRequestBody = (request as http.Request).body;
      return _json({
        'user_code': 'ABCD-EFGH',
        'device_code': 'dc',
        'verification_url': 'https://google.com/device',
        'expires_in': 900,
      });
    }
    if (u.host == 'oauth2.googleapis.com' && u.path.endsWith('/token')) {
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
    if (u.host == 'www.googleapis.com' && u.path.endsWith('/calendarList')) {
      return _json({
        'items': [
          {'id': 'primary', 'summary': 'Primary'}
        ],
      });
    }
    if (u.host == 'www.googleapis.com' && u.path.contains('/events')) {
      return _json({
        'items': [
          {
            'id': 'evt1',
            'summary': 'Hello',
            'iCalUID': 'google-ical-1',
            'start': {'dateTime': '2026-06-01T10:00:00.0000000Z'},
            'end': {'dateTime': '2026-06-01T11:00:00.0000000Z'},
          },
        ],
      });
    }
    return http.StreamedResponse(Stream.value(utf8.encode('')), 404);
  }
}

http.StreamedResponse _json(Object obj) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(obj))),
      200,
      headers: {'Content-Type': 'application/json'},
    );
