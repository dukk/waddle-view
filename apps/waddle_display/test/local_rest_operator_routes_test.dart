import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/alerts/drift_alert_repository.dart';
import 'package:waddle_display/api/deployment_api_key_source.dart';
import 'package:waddle_display/api/local_rest_server.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/curator/ticker_item.dart';
import 'package:waddle_display/debug/operator_telemetry_hub.dart';
import 'package:waddle_display/display/display_navigation_bus.dart';
import 'package:waddle_display/ticker/memory_ticker_curated_repository.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'helpers/memory_database.dart';

void main() {
  test('telemetry and navigation endpoints', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final hub = OperatorTelemetryHub(maxProviderLines: 10);
    hub.addProviderLine('hello');
    final nav = DisplayNavigationBus();
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('secret');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('secret'),
      setupScreenId: 'admin_setup',
      telemetryHub: hub,
      navigationBus: nav,
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final tel = await http.get(
        Uri.parse('${server.baseUrl}/v1/telemetry/providers'),
        headers: {'x-api-key': 'secret'},
      );
      expect(tel.statusCode, 200);
      final telBody = jsonDecode(tel.body) as Map<String, dynamic>;
      expect((telBody['items'] as List).length, 1);

      final navRes = await http.post(
        Uri.parse('${server.baseUrl}/v1/display/navigation'),
        headers: {
          'x-api-key': 'secret',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'surface': 'screen',
          'direction': 'back',
        }),
      );
      expect(navRes.statusCode, 200);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('navigation 503 when bus omitted', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final res = await http.post(
        Uri.parse('${server.baseUrl}/v1/display/navigation'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({'surface': 'screen', 'direction': 'forward'}),
      );
      expect(res.statusCode, 503);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('POST and DELETE screen round-trip', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final post = await http.post(
        Uri.parse('${server.baseUrl}/v1/screens'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'id': 'rest_test_screen',
          'screen_type': 'static_text',
          'config_json': {'text': 'Hi'},
        }),
      );
      expect(post.statusCode, 200);
      final del = await http.delete(
        Uri.parse('${server.baseUrl}/v1/screens/rest_test_screen'),
        headers: {'x-api-key': 'k'},
      );
      expect(del.statusCode, 200);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('GET meta screen-types', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final res = await http.get(
        Uri.parse('${server.baseUrl}/v1/meta/screen-types'),
        headers: {'x-api-key': 'k'},
      );
      expect(res.statusCode, 200);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>;
      expect(items.isNotEmpty, isTrue);
      expect((items.first as Map).containsKey('screen_type'), isTrue);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('GET telemetry programs and ticker-programs', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final hub = OperatorTelemetryHub(maxScreenPrograms: 5, maxTickerPrograms: 5);
    hub.recordScreenProgram(
      reason: 'test',
      slides: const [
        ResolvedSlide(
          screenId: 's1',
          dwellMs: 1000,
          layoutJson: '{"w":1}',
          randomChoices: {},
        ),
      ],
      screenTypeById: const {'s1': 'weather'},
    );
    hub.recordTickerProgram([
      const TickerItem(kind: 'time', body: 't', sourceId: null),
    ]);
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
      telemetryHub: hub,
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final prog = await http.get(
        Uri.parse('${server.baseUrl}/v1/telemetry/programs?limit=10'),
        headers: {'x-api-key': 'k'},
      );
      expect(prog.statusCode, 200);
      final progItems =
          (jsonDecode(prog.body) as Map<String, dynamic>)['items'] as List;
      expect(progItems.length, 1);

      final tick = await http.get(
        Uri.parse('${server.baseUrl}/v1/telemetry/ticker-programs'),
        headers: {'x-api-key': 'k'},
      );
      expect(tick.statusCode, 200);
      final tickItems =
          (jsonDecode(tick.body) as Map<String, dynamic>)['items'] as List;
      expect(tickItems.length, 1);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('ticker navigation POST', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final nav = DisplayNavigationBus();
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
      navigationBus: nav,
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final res = await http.post(
        Uri.parse('${server.baseUrl}/v1/display/navigation'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'surface': 'ticker',
          'direction': 'forward',
        }),
      );
      expect(res.statusCode, 200);
      expect(nav.dequeueTickerNav(), 1);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('navigation validation errors', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final nav = DisplayNavigationBus();
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
      navigationBus: nav,
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final badJson = await http.post(
        Uri.parse('${server.baseUrl}/v1/display/navigation'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: '{',
      );
      expect(badJson.statusCode, 400);

      final badDir = await http.post(
        Uri.parse('${server.baseUrl}/v1/display/navigation'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({'surface': 'screen', 'direction': 'sideways'}),
      );
      expect(badDir.statusCode, 400);

      final badSurf = await http.post(
        Uri.parse('${server.baseUrl}/v1/display/navigation'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({'surface': 'alerts', 'direction': 'forward'}),
      );
      expect(badSurf.statusCode, 400);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('PUT curator settings and PATCH ticker definition', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.tickerDefinitions).insert(
          TickerDefinitionsCompanion.insert(
            id: 'op_tick',
            name: 'Op',
            tickerType: 'time',
            sortOrder: const Value(0),
            frequencyWeight: const Value(50),
            enabled: const Value(true),
          ),
        );
    var configCalls = 0;
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {
        configCalls++;
      },
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final defs = await http.get(
        Uri.parse('${server.baseUrl}/v1/ticker/definitions'),
        headers: {'x-api-key': 'k'},
      );
      expect(defs.statusCode, 200);
      final defItems =
          (jsonDecode(defs.body) as Map<String, dynamic>)['items'] as List;
      expect(defItems.any((e) => (e as Map)['id'] == 'op_tick'), isTrue);

      final patchTick = await http.patch(
        Uri.parse('${server.baseUrl}/v1/ticker/definitions/op_tick'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'enabled': false,
          'frequency_weight': 77,
          'sort_order': 3,
          'config_key': '',
        }),
      );
      expect(patchTick.statusCode, 200);
      expect(configCalls, greaterThan(0));

      final put = await http.put(
        Uri.parse('${server.baseUrl}/v1/curator/settings'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'program_duration_seconds': 120,
          'history_depth': 4,
          'ticker_pixels_per_second': '90',
          'require_news_photo_for_screens': false,
          'display_theme_id': 'graphite_amber',
          'display_text_scale_screen': 'large',
          'display_text_scale_ticker': 'normal',
        }),
      );
      expect(put.statusCode, 200);

      final cur = await http.get(
        Uri.parse('${server.baseUrl}/v1/curator/settings'),
        headers: {'x-api-key': 'k'},
      );
      expect(cur.statusCode, 200);
      final curBody = jsonDecode(cur.body) as Map<String, dynamic>;
      expect(curBody['program_duration_seconds'], 120);
      expect(curBody['history_depth'], 4);
      expect(curBody['require_news_photo_for_screens'], isFalse);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('PATCH ticker 404 and invalid_fields', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final miss = await http.patch(
        Uri.parse('${server.baseUrl}/v1/ticker/definitions/missing'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({'enabled': true}),
      );
      expect(miss.statusCode, 404);

      await db.into(db.tickerDefinitions).insert(
            TickerDefinitionsCompanion.insert(
              id: 'bad_tick',
              name: 'B',
              tickerType: 'quote',
            ),
          );
      final bad = await http.patch(
        Uri.parse('${server.baseUrl}/v1/ticker/definitions/bad_tick'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({'enabled': null}),
      );
      expect(bad.statusCode, 400);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('PATCH provider', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'stock_test',
            providerType: 'stock_finnhub',
            pollSeconds: const Value(120),
            enabled: const Value(true),
            baseUrl: const Value('http://example.invalid'),
            configJson: const Value('{"sym":"AAPL"}'),
          ),
        );
    var calls = 0;
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {
        calls++;
      },
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final list = await http.get(
        Uri.parse('${server.baseUrl}/v1/providers'),
        headers: {'x-api-key': 'k'},
      );
      expect(list.statusCode, 200);
      final items =
          (jsonDecode(list.body) as Map<String, dynamic>)['items'] as List;
      expect(items.any((e) => (e as Map)['id'] == 'stock_test'), isTrue);

      final patch = await http.patch(
        Uri.parse('${server.baseUrl}/v1/providers/stock_test'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'enabled': false,
          'poll_seconds': 999,
          'base_url': null,
          'config_json': {'sym': 'MSFT'},
        }),
      );
      expect(patch.statusCode, 200);
      expect(calls, 1);

      final miss = await http.patch(
        Uri.parse('${server.baseUrl}/v1/providers/nope'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({'enabled': true, 'poll_seconds': 1}),
      );
      expect(miss.statusCode, 404);

      final badCfg = await http.patch(
        Uri.parse('${server.baseUrl}/v1/providers/stock_test'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'enabled': true,
          'poll_seconds': 1,
          'config_json': 3,
        }),
      );
      expect(badCfg.statusCode, 400);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('POST screens validation and PATCH screen', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final emptyId = await http.post(
        Uri.parse('${server.baseUrl}/v1/screens'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'id': '',
          'screen_type': 'static_text',
          'config_json': {},
        }),
      );
      expect(emptyId.statusCode, 400);

      final unknown = await http.post(
        Uri.parse('${server.baseUrl}/v1/screens'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'id': 'x',
          'screen_type': 'not_a_real_widget',
          'config_json': {},
        }),
      );
      expect(unknown.statusCode, 400);

      final ok = await http.post(
        Uri.parse('${server.baseUrl}/v1/screens'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'id': 'patch_me',
          'screen_type': 'static_text',
          'config_json': {'text': 'A'},
        }),
      );
      expect(ok.statusCode, 200);

      final dup = await http.post(
        Uri.parse('${server.baseUrl}/v1/screens'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'id': 'patch_me',
          'screen_type': 'static_text',
          'config_json': {'text': 'B'},
        }),
      );
      expect(dup.statusCode, 409);

      final patch = await http.patch(
        Uri.parse('${server.baseUrl}/v1/screens/patch_me'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'name': 'Renamed',
          'config_json': {'text': 'B'},
        }),
      );
      expect(patch.statusCode, 200);

      final delMiss = await http.delete(
        Uri.parse('${server.baseUrl}/v1/screens/ghost'),
        headers: {'x-api-key': 'k'},
      );
      expect(delMiss.statusCode, 404);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('PUT curator validation', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final bad = await http.put(
        Uri.parse('${server.baseUrl}/v1/curator/settings'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: jsonEncode({'program_duration_seconds': 1}),
      );
      expect(bad.statusCode, 400);

      final badJson = await http.put(
        Uri.parse('${server.baseUrl}/v1/curator/settings'),
        headers: {
          'x-api-key': 'k',
          'content-type': 'application/json',
        },
        body: '[]',
      );
      expect(badJson.statusCode, 400);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('CORS preflight and GET with allowlisted origin', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    const origin = 'http://localhost:5199';
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
      corsAllowedOrigins: const [origin],
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    final client = http.Client();
    try {
      final optReq = http.Request(
        'OPTIONS',
        Uri.parse('${server.baseUrl}/v1/health'),
      )..headers['Origin'] = origin;
      final optRes = await client.send(optReq);
      expect(optRes.statusCode, 204);
      expect(optRes.headers['access-control-allow-origin'], origin);

      final getRes = await client.get(
        Uri.parse('${server.baseUrl}/v1/health'),
        headers: {'Origin': origin},
      );
      expect(getRes.statusCode, 200);
      expect(getRes.headers['access-control-allow-origin'], origin);
    } finally {
      client.close();
      await server.close();
      await db.close();
    }
  });

  test('GET curator settings', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final res = await http.get(
        Uri.parse('${server.baseUrl}/v1/curator/settings'),
        headers: {'x-api-key': 'k'},
      );
      expect(res.statusCode, 200);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body.containsKey('program_duration_seconds'), isTrue);
    } finally {
      await server.close();
      await db.close();
    }
  });
}

Future<File> _tempKeyFile(String contents) async {
  final f = File(
    '${Directory.systemTemp.path}/waddle_key_${DateTime.now().microsecondsSinceEpoch}.txt',
  );
  await f.writeAsString('$contents\n');
  return f;
}
