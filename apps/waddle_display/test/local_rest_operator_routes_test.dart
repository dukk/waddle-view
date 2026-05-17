import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/curator/ticker_item.dart';
import 'package:waddle_display/debug/operator_telemetry_hub.dart';
import 'package:waddle_display/display/display_navigation_bus.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import 'helpers/fake_blob_store.dart';
import 'helpers/memory_database.dart';
import 'helpers/rest_auth_helper.dart';

void main() {
  test('telemetry and navigation endpoints', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final hub = OperatorTelemetryHub(maxIntegrationLines: 10);
    hub.addIntegrationLine('hello');
    final nav = DisplayNavigationBus();
    final h = await RestTestHarness.start(
      database: db,
      telemetryHub: hub,
      navigationBus: nav,
    );
    addTearDown(h.dispose);

    final tel = await http.get(
      Uri.parse('${h.baseUrl}/v1/telemetry/integrations'),
      headers: h.authHeaders,
    );
    expect(tel.statusCode, 200);
    final telBody = jsonDecode(tel.body) as Map<String, dynamic>;
    expect((telBody['items'] as List).length, 1);

    final navRes = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/navigation'),
      headers: h.authHeaders,
      body: jsonEncode({
        'surface': 'screen',
        'direction': 'back',
      }),
    );
    expect(navRes.statusCode, 200);
  });

  test('navigation 503 when bus omitted', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/navigation'),
      headers: h.authHeaders,
      body: jsonEncode({'surface': 'screen', 'direction': 'forward'}),
    );
    expect(res.statusCode, 503);
  });

  test('POST and DELETE screen round-trip', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/screens'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'rest_test_screen',
        'screen_type': 'static_text',
        'config_json': {'text': 'Hi'},
      }),
    );
    expect(post.statusCode, 200);
    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/screens/rest_test_screen'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 200);
  });

  test('GET meta screen-types', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/meta/screen-types'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>;
    expect(items.isNotEmpty, isTrue);
    expect((items.first as Map).containsKey('screen_type'), isTrue);
  });

  test('GET meta ticker-types', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/meta/ticker-types'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>;
    expect(items.isNotEmpty, isTrue);
    expect((items.first as Map).containsKey('ticker_type'), isTrue);
  });

  test('POST and DELETE ticker tape round-trip', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/ticker/tapes'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'rest_test_tape',
        'ticker_type': 'time',
        'name': 'Test clock',
      }),
    );
    expect(post.statusCode, 200);
    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/ticker/tapes/rest_test_tape'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 200);
  });

  test('GET telemetry programs and ticker-programs', () async {
    final hub =
        OperatorTelemetryHub(maxScreenPrograms: 5, maxTickerPrograms: 5);
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
    final h = await RestTestHarness.start(
      telemetryHub: hub,
    );
    addTearDown(h.dispose);

    final prog = await http.get(
      Uri.parse('${h.baseUrl}/v1/telemetry/programs?limit=10'),
      headers: h.authHeaders,
    );
    expect(prog.statusCode, 200);
    final progItems =
        (jsonDecode(prog.body) as Map<String, dynamic>)['items'] as List;
    expect(progItems.length, 1);

    final tick = await http.get(
      Uri.parse('${h.baseUrl}/v1/telemetry/ticker-programs'),
      headers: h.authHeaders,
    );
    expect(tick.statusCode, 200);
    final tickItems =
        (jsonDecode(tick.body) as Map<String, dynamic>)['items'] as List;
    expect(tickItems.length, 1);
  });

  test('GET media rss-articles and blob-by-key', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'f_media_test',
            url: 'https://example.com/feed.xml',
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'art_media_test',
            feedId: 'f_media_test',
            guid: 'g_media',
            title: 'Headline',
            link: 'https://example.com/a',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(10),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(20),
            imageBlobKey: const Value('img_blob_k'),
          ),
        );
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'img_blob_k',
            sha256: List.filled(64, '0').join(),
            relativePath: 'aa/bb/ccfeed',
            bytes: 3,
            mimeType: const Value('image/png'),
            capturedAt: DateTime.fromMillisecondsSinceEpoch(30),
          ),
        );
    final fake = FakeBlobStore()..seed('aa/bb/ccfeed', [10, 20, 30]);
    final h = await RestTestHarness.start(database: db, blobStore: fake);
    addTearDown(h.dispose);

    final j = await http.get(
      Uri.parse('${h.baseUrl}/v1/media/rss-articles/art_media_test'),
      headers: h.authHeaders,
    );
    expect(j.statusCode, 200);
    final map = jsonDecode(j.body) as Map<String, dynamic>;
    expect(map['title'], 'Headline');
    expect(map['image_blob_key'], 'img_blob_k');

    final img = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/media/blob-by-key?key=${Uri.encodeComponent('img_blob_k')}',
      ),
      headers: h.authHeaders,
    );
    expect(img.statusCode, 200);
    expect(img.bodyBytes, [10, 20, 30]);
    expect(img.headers['content-type'], contains('image/png'));
  });

  test('ticker navigation POST', () async {
    final nav = DisplayNavigationBus();
    final h = await RestTestHarness.start(
      navigationBus: nav,
    );
    addTearDown(h.dispose);

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/navigation'),
      headers: h.authHeaders,
      body: jsonEncode({
        'surface': 'ticker',
        'direction': 'forward',
      }),
    );
    expect(res.statusCode, 200);
    expect(nav.dequeueTickerNav(), 1);
  });

  test('power_viewer may POST display navigation', () async {
    final nav = DisplayNavigationBus();
    final h = await RestTestHarness.start(
      role: kUserRolePowerViewer,
      navigationBus: nav,
    );
    addTearDown(h.dispose);

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/navigation'),
      headers: h.authHeaders,
      body: jsonEncode({
        'surface': 'screen',
        'direction': 'forward',
      }),
    );
    expect(res.statusCode, 200);
    expect(nav.dequeueScreenNav(), 1);
  });

  test('GET media weather-at-location', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.weatherLocations).insert(
          WeatherLocationsCompanion.insert(
            id: 'den',
            name: 'Denver',
            latitude: 39,
            longitude: -105,
          ),
        );
    await db.into(db.weatherCurrent).insert(
          WeatherCurrentCompanion.insert(
            locationId: 'den',
            observedAtMs: DateTime.utc(2026, 1, 1),
            currentTemp: const Value(5),
            currentDescription: const Value('snow'),
          ),
        );
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/media/weather-at-location/den'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    expect(m['location_name'], 'Denver');
    expect(m['current_temp_c'], 5);
    expect(m['current_description'], 'snow');
  });

  test('navigation validation errors', () async {
    final nav = DisplayNavigationBus();
    final h = await RestTestHarness.start(
      navigationBus: nav,
    );
    addTearDown(h.dispose);

    final badJson = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/navigation'),
      headers: h.authHeaders,
      body: '{',
    );
    expect(badJson.statusCode, 400);

    final badDir = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/navigation'),
      headers: h.authHeaders,
      body: jsonEncode({'surface': 'screen', 'direction': 'sideways'}),
    );
    expect(badDir.statusCode, 400);

    final badSurf = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/navigation'),
      headers: h.authHeaders,
      body: jsonEncode({'surface': 'alerts', 'direction': 'forward'}),
    );
    expect(badSurf.statusCode, 400);
  });

  test('PUT curator settings and PATCH ticker tape', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.tickerTapes).insert(
          TickerTapesCompanion.insert(
            id: 'op_tick',
            name: 'Op',
            tickerType: 'time',
            sortOrder: const Value(0),
            frequencyWeight: const Value(50),
          ),
        );
    var configCalls = 0;
    final h = await RestTestHarness.start(
      database: db,
      onConfigChanged: () async {
        configCalls++;
      },
    );
    addTearDown(h.dispose);

    final defs = await http.get(
      Uri.parse('${h.baseUrl}/v1/ticker/tapes'),
      headers: h.authHeaders,
    );
    expect(defs.statusCode, 200);
    final defItems =
        (jsonDecode(defs.body) as Map<String, dynamic>)['items'] as List;
    expect(defItems.any((e) => (e as Map)['id'] == 'op_tick'), isTrue);

    final patchTick = await http.patch(
      Uri.parse('${h.baseUrl}/v1/ticker/tapes/op_tick'),
      headers: h.authHeaders,
      body: jsonEncode({
        'frequency_weight': 77,
        'sort_order': 3,
        'config_key': '',
      }),
    );
    expect(patchTick.statusCode, 200);
    expect(configCalls, greaterThan(0));

    final put = await http.put(
      Uri.parse('${h.baseUrl}/v1/curator/settings'),
      headers: h.authHeaders,
      body: jsonEncode({
        'ticker_pixels_per_second': '90',
        'display_theme_id': 'graphite_amber',
        'display_text_scale_screen': 'large',
        'display_text_scale_ticker': 'normal',
      }),
    );
    expect(put.statusCode, 200);

    final cur = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/settings'),
      headers: h.authHeaders,
    );
    expect(cur.statusCode, 200);
    final curBody = jsonDecode(cur.body) as Map<String, dynamic>;
    expect(curBody['ticker_pixels_per_second'], '90');
    expect(curBody['display_theme_id'], 'graphite_amber');
  });

  test('PATCH ticker tape 404 and invalid_fields', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final miss = await http.patch(
      Uri.parse('${h.baseUrl}/v1/ticker/tapes/missing'),
      headers: h.authHeaders,
      body: jsonEncode({'frequency_weight': 1}),
    );
    expect(miss.statusCode, 404);

    await h.db.into(h.db.tickerTapes).insert(
          TickerTapesCompanion.insert(
            id: 'bad_tick',
            name: 'B',
            tickerType: 'quote',
          ),
        );
    final bad = await http.patch(
      Uri.parse('${h.baseUrl}/v1/ticker/tapes/bad_tick'),
      headers: h.authHeaders,
      body: jsonEncode({'frequency_weight': null}),
    );
    expect(bad.statusCode, 400);
  });

  test('PATCH provider', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: 'stock_test',
            providerType: 'stock_finnhub',
            pollSeconds: const Value(120),
            enabled: const Value(true),
            baseUrl: const Value('http://example.invalid'),
            configJson: const Value('{"sym":"AAPL"}'),
          ),
        );
    var calls = 0;
    final h = await RestTestHarness.start(
      database: db,
      onConfigChanged: () async {
        calls++;
      },
    );
    addTearDown(h.dispose);

    final list = await http.get(
      Uri.parse('${h.baseUrl}/v1/integrations'),
      headers: h.authHeaders,
    );
    expect(list.statusCode, 200);
    final items =
        (jsonDecode(list.body) as Map<String, dynamic>)['items'] as List;
    expect(items.any((e) => (e as Map)['id'] == 'stock_test'), isTrue);

    final patch = await http.patch(
      Uri.parse('${h.baseUrl}/v1/integrations/stock_test'),
      headers: h.authHeaders,
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
      Uri.parse('${h.baseUrl}/v1/integrations/nope'),
      headers: h.authHeaders,
      body: jsonEncode({'enabled': true, 'poll_seconds': 1}),
    );
    expect(miss.statusCode, 404);

    final badCfg = await http.patch(
      Uri.parse('${h.baseUrl}/v1/integrations/stock_test'),
      headers: h.authHeaders,
      body: jsonEncode({
        'enabled': true,
        'poll_seconds': 1,
        'config_json': 3,
      }),
    );
    expect(badCfg.statusCode, 400);
  });

  test('POST screens validation and PATCH screen', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final emptyId = await http.post(
      Uri.parse('${h.baseUrl}/v1/screens'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': '',
        'screen_type': 'static_text',
        'config_json': {},
      }),
    );
    expect(emptyId.statusCode, 400);

    final unknown = await http.post(
      Uri.parse('${h.baseUrl}/v1/screens'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'x',
        'screen_type': 'not_a_real_widget',
        'config_json': {},
      }),
    );
    expect(unknown.statusCode, 400);

    final ok = await http.post(
      Uri.parse('${h.baseUrl}/v1/screens'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'patch_me',
        'screen_type': 'static_text',
        'config_json': {'text': 'A'},
      }),
    );
    expect(ok.statusCode, 200);

    final dup = await http.post(
      Uri.parse('${h.baseUrl}/v1/screens'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'patch_me',
        'screen_type': 'static_text',
        'config_json': {'text': 'B'},
      }),
    );
    expect(dup.statusCode, 409);

    final patch = await http.patch(
      Uri.parse('${h.baseUrl}/v1/screens/patch_me'),
      headers: h.authHeaders,
      body: jsonEncode({
        'name': 'Renamed',
        'config_json': {'text': 'B'},
      }),
    );
    expect(patch.statusCode, 200);

    final delMiss = await http.delete(
      Uri.parse('${h.baseUrl}/v1/screens/ghost'),
      headers: h.authHeaders,
    );
    expect(delMiss.statusCode, 404);
  });

  test('PUT curator settings rejects empty update', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final empty = await http.put(
      Uri.parse('${h.baseUrl}/v1/curator/settings'),
      headers: h.authHeaders,
      body: jsonEncode({}),
    );
    expect(empty.statusCode, 400);

    final badJson = await http.put(
      Uri.parse('${h.baseUrl}/v1/curator/settings'),
      headers: h.authHeaders,
      body: '[]',
    );
    expect(badJson.statusCode, 400);
  });

  test('PUT curator settings allows partial updates', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final partial = await http.put(
      Uri.parse('${h.baseUrl}/v1/curator/settings'),
      headers: h.authHeaders,
      body: jsonEncode({'ticker_pixels_per_second': '42'}),
    );
    expect(partial.statusCode, 200);

    final cur = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/settings'),
      headers: h.authHeaders,
    );
    expect(cur.statusCode, 200);
    final curBody = jsonDecode(cur.body) as Map<String, dynamic>;
    expect(curBody['ticker_pixels_per_second'], '42');
  });

  test('CORS preflight and GET with allowlisted origin', () async {
    const origin = 'http://localhost:5199';
    final h = await RestTestHarness.start(
      seedCorsOrigins: const [origin],
    );
    addTearDown(h.dispose);

    final client = http.Client();
    try {
      final optReq = http.Request(
        'OPTIONS',
        Uri.parse('${h.baseUrl}/v1/health'),
      )..headers['Origin'] = origin;
      final optRes = await client.send(optReq);
      expect(optRes.statusCode, 204);
      expect(optRes.headers['access-control-allow-origin'], origin);

      final getRes = await client.get(
        Uri.parse('${h.baseUrl}/v1/health'),
        headers: {'Origin': origin},
      );
      expect(getRes.statusCode, 200);
      expect(getRes.headers['access-control-allow-origin'], origin);
    } finally {
      client.close();
    }
  });

  test('curator categories CRUD', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/curator/categories'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'ctl_test_cat',
        'label': 'Ctl test',
        'material_icon_name': 'star',
      }),
    );
    expect(post.statusCode, 200);

    final list = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/categories'),
      headers: h.authHeaders,
    );
    expect(list.statusCode, 200);
    final items =
        (jsonDecode(list.body) as Map<String, dynamic>)['items'] as List<dynamic>;
    expect(
      items.any((e) => (e as Map<String, dynamic>)['id'] == 'ctl_test_cat'),
      isTrue,
    );

    final patch = await http.patch(
      Uri.parse('${h.baseUrl}/v1/curator/categories/ctl_test_cat'),
      headers: h.authHeaders,
      body: jsonEncode({'label': 'Ctl test renamed'}),
    );
    expect(patch.statusCode, 200);

    final delReserved = await http.delete(
      Uri.parse('${h.baseUrl}/v1/curator/categories/general'),
      headers: h.authHeaders,
    );
    expect(delReserved.statusCode, 403);

    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/curator/categories/ctl_test_cat'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 200);
  });

  test('GET curator settings', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/settings'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body.containsKey('ticker_pixels_per_second'), isTrue);
    expect(body['display_timezone'], isNotNull);
    expect(body.containsKey('program_duration_seconds'), isFalse);
  });

  test('PUT curator settings display_timezone and config key-values REST', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final putTz = await http.put(
      Uri.parse('${h.baseUrl}/v1/curator/settings'),
      headers: h.authHeaders,
      body: jsonEncode({'display_timezone': 'America/Chicago'}),
    );
    expect(putTz.statusCode, 200);

    final cur = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/settings'),
      headers: h.authHeaders,
    );
    expect(cur.statusCode, 200);
    expect(
      (jsonDecode(cur.body) as Map<String, dynamic>)['display_timezone'],
      'America/Chicago',
    );

    final list = await http.get(
      Uri.parse('${h.baseUrl}/v1/config/key-values'),
      headers: h.authHeaders,
    );
    expect(list.statusCode, 200);
    final items =
        (jsonDecode(list.body) as Map<String, dynamic>)['items'] as List<dynamic>;
    expect(
      items.any((e) {
        final m = e as Map<String, dynamic>;
        return m['key'] == kDisplayTimezoneKvKey && m['value'] == 'America/Chicago';
      }),
      isTrue,
    );

    final upsert = await http.put(
      Uri.parse('${h.baseUrl}/v1/config/key-values'),
      headers: h.authHeaders,
      body: jsonEncode({'key': 'ctl.kv.test', 'value': 'hello'}),
    );
    expect(upsert.statusCode, 200);

    final delMiss = await http.delete(
      Uri.parse('${h.baseUrl}/v1/config/key-values?key=${Uri.encodeComponent('nope')}'),
      headers: h.authHeaders,
    );
    expect(delMiss.statusCode, 404);

    final delOk = await http.delete(
      Uri.parse('${h.baseUrl}/v1/config/key-values?key=${Uri.encodeComponent('ctl.kv.test')}'),
      headers: h.authHeaders,
    );
    expect(delOk.statusCode, 200);

    final badPut = await http.put(
      Uri.parse('${h.baseUrl}/v1/config/key-values'),
      headers: h.authHeaders,
      body: jsonEncode({'value': 'x'}),
    );
    expect(badPut.statusCode, 400);
  });
}
