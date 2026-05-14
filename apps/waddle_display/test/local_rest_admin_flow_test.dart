import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/alerts/drift_alert_repository.dart';
import 'package:waddle_display/api/deployment_api_key_source.dart';
import 'package:waddle_display/api/local_rest_server.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_display/theme/config/display_theme_registry.dart';
import 'package:waddle_shared/theme/display_text_scale_kv.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';
import 'package:waddle_display/ticker/memory_ticker_curated_repository.dart';

import 'helpers/memory_database.dart';

const _adminPw = 'test-admin-password';

String _firstCsrf(String html) =>
    RegExp(r'name="csrf" value="([^"]+)"').firstMatch(html)!.group(1)!;

Future<File> _tempKeyFile(String value) async {
  final dir = await Directory.systemTemp.createTemp('wv_admin_flow_');
  final file = File('${dir.path}/waddle_api.key');
  await file.writeAsString('$value\n', flush: true);
  return file;
}

Future<http.Response> _getWithoutRedirect(
  Uri uri, {
  Map<String, String>? headers,
}) async {
  final request = http.Request('GET', uri);
  if (headers != null) {
    request.headers.addAll(headers);
  }
  request.followRedirects = false;
  final client = http.Client();
  try {
    final streamed = await client.send(request);
    return await http.Response.fromStream(streamed);
  } finally {
    client.close();
  }
}

Future<({String cookie, String csrf})> _loginSession(
  LocalRestServer server,
  String password,
) async {
  final login = await http.post(
    Uri.parse('${server.baseUrl}/admin/login'),
    headers: {'content-type': 'application/x-www-form-urlencoded'},
    body: 'password=${Uri.encodeQueryComponent(password)}',
  );
  expect(login.statusCode, 302);
  final cookie = login.headers['set-cookie'];
  expect(cookie, isNotNull);
  final home = await http.get(
    Uri.parse('${server.baseUrl}/admin'),
    headers: {'cookie': cookie!},
  );
  expect(home.statusCode, 200);
  return (cookie: cookie, csrf: _firstCsrf(home.body));
}

void main() {
  test('GET login page renders form', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final keyFile = await _tempKeyFile(_adminPw);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: DriftAlertRepository(db),
      keys: FakeDeploymentApiKeySource(_adminPw),
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: keyFile,
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final res = await http.get(Uri.parse('${server.baseUrl}/admin/login'));
      expect(res.statusCode, 200);
      expect(res.body, contains('Waddle View Admin Login'));
      expect(res.body, contains('type="password"'));
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('POST login rejects wrong password', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final keyFile = await _tempKeyFile(_adminPw);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: DriftAlertRepository(db),
      keys: FakeDeploymentApiKeySource(_adminPw),
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: keyFile,
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final res = await http.post(
        Uri.parse('${server.baseUrl}/admin/login'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: 'password=nope',
      );
      expect(res.statusCode, 401);
      expect(res.body, contains('Invalid password'));
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('unknown admin path returns 404', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final keyFile = await _tempKeyFile(_adminPw);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: DriftAlertRepository(db),
      keys: FakeDeploymentApiKeySource(_adminPw),
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: keyFile,
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final res = await http.get(Uri.parse('${server.baseUrl}/admin/nosuch'));
      expect(res.statusCode, 404);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test(
    'admin home update-curator update-screen update-provider and logout',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      await db.into(db.configKeyValues).insert(
            ConfigKeyValuesCompanion.insert(
              key: kAdminBootstrapDoneKvKey,
              value: '1',
            ),
          );
      await db.into(db.screenDefinitions).insert(
            ScreenDefinitionsCompanion.insert(
              id: 'screen_a',
              name: 'Alpha',
              screenType: 'static_text',
              dwellSeconds: const Value(10),
              frequencyWeight: const Value(100),
            ),
          );
      await db.into(db.providerSettings).insert(
            ProviderSettingsCompanion.insert(
              id: 'joke_openai',
              providerType: 'joke_openai',
              pollSeconds: const Value(60),
              baseUrl: const Value('http://openai.test'),
              configJson: const Value('{}'),
            ),
          );

      final keyFile = await _tempKeyFile(_adminPw);
      final ticker = MemoryTickerCuratedRepository();
      addTearDown(ticker.dispose);
      var configCallbacks = 0;
      final handler = buildRootHandler(
        db: db,
        alerts: DriftAlertRepository(db),
        keys: FakeDeploymentApiKeySource(_adminPw),
        ticker: ticker,
        onConfigChanged: () async {
          configCallbacks++;
        },
        keyFile: keyFile,
        setupScreenId: 'admin_setup',
      );
      final server = await LocalRestServer.bind(handler: handler, port: 0);
      try {
        final s = await _loginSession(server, _adminPw);

        final curatorBody =
            'csrf=${Uri.encodeQueryComponent(s.csrf)}'
            '&program_duration_seconds=240'
            '&history_depth=7'
            '&require_news_photo_for_screens=on'
            '&ticker_pixels_per_second=92'
            '&display_theme_id=$kDisplayThemeGraphiteAmber'
            '&display_text_scale_screen=$kDisplayTextScaleNormal'
            '&display_text_scale_ticker=$kDisplayTextScaleLarge';

        final cur = await http.post(
          Uri.parse('${server.baseUrl}/admin/update-curator'),
          headers: {
            'cookie': s.cookie,
            'content-type': 'application/x-www-form-urlencoded',
          },
          body: curatorBody,
        );
        expect(cur.statusCode, 302);
        expect(cur.headers['location'], '/admin');

        final kvDur = await (db.select(db.configKeyValues)
              ..where((t) => t.key.equals(kCuratorProgramDurationSecondsKvKey)))
            .getSingle();
        expect(kvDur.value, '240');
        final kvHist = await (db.select(db.configKeyValues)
              ..where((t) => t.key.equals(kCuratorHistoryDepthKvKey)))
            .getSingle();
        expect(kvHist.value, '7');
        final kvNewsPhoto = await (db.select(db.configKeyValues)
              ..where((t) => t.key.equals(kRequireNewsPhotoForScreensKvKey)))
            .getSingle();
        expect(kvNewsPhoto.value, 'true');
        final kvTicker = await (db.select(db.configKeyValues)
              ..where((t) => t.key.equals('curator.ticker.newsPixelsPerSecond')))
            .getSingle();
        expect(kvTicker.value, '92');
        final kvTheme = await (db.select(db.configKeyValues)
              ..where((t) => t.key.equals(kDisplayThemeIdKvKey)))
            .getSingle();
        expect(kvTheme.value, kDisplayThemeGraphiteAmber);

        final screenBody =
            'csrf=${Uri.encodeQueryComponent(s.csrf)}'
            '&id=screen_a'
            '&name=Renamed'
            '&enabled=on'
            '&dwell_seconds=22'
            '&frequency_weight=55'
            '&min_gap_between_shows_seconds=3';

        final scr = await http.post(
          Uri.parse('${server.baseUrl}/admin/update-screen'),
          headers: {
            'cookie': s.cookie,
            'content-type': 'application/x-www-form-urlencoded',
          },
          body: screenBody,
        );
        expect(scr.statusCode, 302);
        final row = await (db.select(db.screenDefinitions)
              ..where((t) => t.id.equals('screen_a')))
            .getSingle();
        expect(row.name, 'Renamed');
        expect(row.enabled, isTrue);
        expect(row.dwellSeconds, 22);
        expect(row.frequencyWeight, 55);
        expect(row.minGapBetweenShowsSeconds, 3);

        final provBody =
            'csrf=${Uri.encodeQueryComponent(s.csrf)}'
            '&id=joke_openai'
            '&enabled=on'
            '&poll_seconds=99'
            '&base_url=http%3A%2F%2Fapi.updated'
            '&config_json=%7B%22x%22%3A1%7D';

        final prov = await http.post(
          Uri.parse('${server.baseUrl}/admin/update-provider'),
          headers: {
            'cookie': s.cookie,
            'content-type': 'application/x-www-form-urlencoded',
          },
          body: provBody,
        );
        expect(prov.statusCode, 302);
        final ps = await (db.select(db.providerSettings)
              ..where((t) => t.id.equals('joke_openai')))
            .getSingle();
        expect(ps.pollSeconds, 99);
        expect(ps.baseUrl, 'http://api.updated');
        expect(ps.configJson, '{"x":1}');

        expect(configCallbacks >= 3, isTrue);

        final out = await _getWithoutRedirect(
          Uri.parse('${server.baseUrl}/admin/logout'),
          headers: {'cookie': s.cookie},
        );
        expect(out.statusCode, 302);

        final blocked = await _getWithoutRedirect(
          Uri.parse('${server.baseUrl}/admin'),
          headers: {'cookie': s.cookie},
        );
        expect(blocked.statusCode, 302);
        expect(blocked.headers['location'], contains('login'));
      } finally {
        await server.close();
        await db.close();
      }
    },
  );

  test('update-screen returns 400 when fields invalid', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: kAdminBootstrapDoneKvKey,
            value: '1',
          ),
        );
    final keyFile = await _tempKeyFile(_adminPw);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: DriftAlertRepository(db),
      keys: FakeDeploymentApiKeySource(_adminPw),
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: keyFile,
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final s = await _loginSession(server, _adminPw);
      final res = await http.post(
        Uri.parse('${server.baseUrl}/admin/update-screen'),
        headers: {
          'cookie': s.cookie,
          'content-type': 'application/x-www-form-urlencoded',
        },
        body:
            'csrf=${Uri.encodeQueryComponent(s.csrf)}&id=&name=x&dwell_seconds=1&frequency_weight=1&min_gap_between_shows_seconds=0',
      );
      expect(res.statusCode, 400);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('update-curator returns 400 when integers invalid', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: kAdminBootstrapDoneKvKey,
            value: '1',
          ),
        );
    final keyFile = await _tempKeyFile(_adminPw);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: DriftAlertRepository(db),
      keys: FakeDeploymentApiKeySource(_adminPw),
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: keyFile,
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final s = await _loginSession(server, _adminPw);
      final res = await http.post(
        Uri.parse('${server.baseUrl}/admin/update-curator'),
        headers: {
          'cookie': s.cookie,
          'content-type': 'application/x-www-form-urlencoded',
        },
        body:
            'csrf=${Uri.encodeQueryComponent(s.csrf)}&program_duration_seconds=bad&history_depth=1',
      );
      expect(res.statusCode, 400);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('admin home redirects to change-password when bootstrap incomplete',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final keyFile = await _tempKeyFile(_adminPw);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: DriftAlertRepository(db),
      keys: FakeDeploymentApiKeySource(_adminPw),
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: keyFile,
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final login = await http.post(
        Uri.parse('${server.baseUrl}/admin/login'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: 'password=${Uri.encodeQueryComponent(_adminPw)}',
      );
      expect(login.statusCode, 302);
      final cookie = login.headers['set-cookie'];
      expect(cookie, isNotNull);
      final r = await _getWithoutRedirect(
        Uri.parse('${server.baseUrl}/admin'),
        headers: {'cookie': cookie!},
      );
      expect(r.statusCode, 302);
      expect(r.headers['location'], '/admin/change-password');
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('change-password rotates key file clears sessions and sets bootstrap',
      () async {
    const initial = 'initial-pass-12';
    const rotated = 'rotated-pass-12';
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final keyFile = await _tempKeyFile(initial);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: DriftAlertRepository(db),
      keys: FileDeploymentApiKeySource(keyFile),
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: keyFile,
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final login = await http.post(
        Uri.parse('${server.baseUrl}/admin/login'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: 'password=${Uri.encodeQueryComponent(initial)}',
      );
      expect(login.statusCode, 302);
      final cookie = login.headers['set-cookie']!;
      final changePage = await http.get(
        Uri.parse('${server.baseUrl}/admin/change-password'),
        headers: {'cookie': cookie},
      );
      expect(changePage.statusCode, 200);
      final csrf = _firstCsrf(changePage.body);
      final done = await http.post(
        Uri.parse('${server.baseUrl}/admin/change-password'),
        headers: {
          'cookie': cookie,
          'content-type': 'application/x-www-form-urlencoded',
        },
        body:
            'csrf=${Uri.encodeQueryComponent(csrf)}'
            '&password=${Uri.encodeQueryComponent(rotated)}'
            '&confirm_password=${Uri.encodeQueryComponent(rotated)}',
      );
      expect(done.statusCode, 302);
      expect(done.headers['location'], '/admin/login');
      expect((await keyFile.readAsString()).trim(), rotated);

      final kv = await (db.select(db.configKeyValues)
            ..where((t) => t.key.equals(kAdminBootstrapDoneKvKey)))
          .getSingleOrNull();
      expect(kv?.value, '1');

      final stale = await _getWithoutRedirect(
        Uri.parse('${server.baseUrl}/admin/change-password'),
        headers: {'cookie': cookie},
      );
      expect(stale.statusCode, 302);

      final login2 = await http.post(
        Uri.parse('${server.baseUrl}/admin/login'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: 'password=${Uri.encodeQueryComponent(rotated)}',
      );
      expect(login2.statusCode, 302);
      final cookie2 = login2.headers['set-cookie']!;
      final home = await http.get(
        Uri.parse('${server.baseUrl}/admin'),
        headers: {'cookie': cookie2},
      );
      expect(home.statusCode, 200);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('change-password returns 400 when password invalid', () async {
    const initial = 'initial-pass-12';
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final keyFile = await _tempKeyFile(initial);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: DriftAlertRepository(db),
      keys: FileDeploymentApiKeySource(keyFile),
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: keyFile,
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final login = await http.post(
        Uri.parse('${server.baseUrl}/admin/login'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: 'password=${Uri.encodeQueryComponent(initial)}',
      );
      final cookie = login.headers['set-cookie']!;
      final changePage = await http.get(
        Uri.parse('${server.baseUrl}/admin/change-password'),
        headers: {'cookie': cookie},
      );
      final csrf = _firstCsrf(changePage.body);
      final bad = await http.post(
        Uri.parse('${server.baseUrl}/admin/change-password'),
        headers: {
          'cookie': cookie,
          'content-type': 'application/x-www-form-urlencoded',
        },
        body:
            'csrf=${Uri.encodeQueryComponent(csrf)}'
            '&password=short'
            '&confirm_password=short',
      );
      expect(bad.statusCode, 400);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('update with bad csrf is forbidden', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: kAdminBootstrapDoneKvKey,
            value: '1',
          ),
        );
    final keyFile = await _tempKeyFile(_adminPw);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: DriftAlertRepository(db),
      keys: FakeDeploymentApiKeySource(_adminPw),
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: keyFile,
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final s = await _loginSession(server, _adminPw);
      final res = await http.post(
        Uri.parse('${server.baseUrl}/admin/update-curator'),
        headers: {
          'cookie': s.cookie,
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: 'csrf=wrong&program_duration_seconds=1&history_depth=1',
      );
      expect(res.statusCode, 403);
    } finally {
      await server.close();
      await db.close();
    }
  });
}
