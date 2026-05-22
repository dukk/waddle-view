import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/seed/initial_seed.dart';

import '../helpers/memory_database.dart';
import '../helpers/rest_auth_helper.dart';

void main() {
  test('GET curator meta, runtime-state, active, and configurations', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final predicates = await http.get(
      Uri.parse('${h.baseUrl}/v1/meta/curator-state-predicates'),
      headers: h.authHeaders,
    );
    expect(predicates.statusCode, 200);
    final predBody = jsonDecode(predicates.body) as Map<String, dynamic>;
    expect((predBody['items'] as List), isNotEmpty);

    final runtime = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/runtime-state'),
      headers: h.authHeaders,
    );
    expect(runtime.statusCode, 200);
    final runtimeBody = jsonDecode(runtime.body) as Map<String, dynamic>;
    expect(runtimeBody['display_adopted'], isTrue);

    final active = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/active'),
      headers: h.authHeaders,
    );
    expect(active.statusCode, 200);
    final activeBody = jsonDecode(active.body) as Map<String, dynamic>;
    expect(activeBody['base'], isNotNull);

    final list = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations'),
      headers: h.authHeaders,
    );
    expect(list.statusCode, 200);
    final items =
        (jsonDecode(list.body) as Map<String, dynamic>)['items'] as List;
    expect(items.any((e) => (e as Map)['id'] == 'evening'), isTrue);
    expect(items.any((e) => (e as Map)['id'] == 'default'), isTrue);

    final detail = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/evening'),
      headers: h.authHeaders,
    );
    expect(detail.statusCode, 200);
    final detailBody = jsonDecode(detail.body) as Map<String, dynamic>;
    expect(detailBody['id'], 'evening');
    expect(detailBody['parent_configuration_id'], 'default');
    expect(detailBody['members'], isA<Map>());
    expect(detailBody['rules'], isA<List>());
    expect(detailBody['screens_enabled'], isTrue);
    expect(detailBody['ticker_enabled'], isTrue);
    expect(detailBody['ticker_program_duration_seconds'], isNull);
    expect(detailBody['ticker_pixels_per_second'], isNull);
  });

  test('POST PATCH DELETE curator configuration lifecycle', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final create = await http.post(
      Uri.parse('${h.baseUrl}/v1/curator/configurations'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'test_enhancement',
        'name': 'Test',
        'layer': 'enhancement',
        'sort_order': 50,
        'ticker_program_duration_seconds': 420,
        'ticker_pixels_per_second': 95,
        'rules': [
          {
            'id': 'r1',
            'priority': 1,
            'start_month': 12,
            'start_day': 25,
            'repeat_annually': true,
          },
        ],
        'theme_id_override': 'theme_dark',
        'viewport_reserve_top_pct_override': 12,
        'ticker_enabled': false,
        'screens_enabled': false,
        'members': {
          'screens': ['jokes'],
          'tickers': ['tape_news'],
          'overlays': ['overlay_confetti'],
        },
      }),
    );
    expect(create.statusCode, 200);

    final created = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_enhancement'),
      headers: h.authHeaders,
    );
    expect(created.statusCode, 200);
    final createdBody = jsonDecode(created.body) as Map<String, dynamic>;
    expect(createdBody['theme_id_override'], isNull);
    expect(createdBody['viewport_reserve_top_pct_override'], isNull);
    expect(createdBody['screens_enabled'], isTrue);
    expect(createdBody['ticker_enabled'], isTrue);
    expect(
      (createdBody['members'] as Map)['screens'] as List,
      contains('jokes'),
    );

    final patch = await http.patch(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_enhancement'),
      headers: h.authHeaders,
      body: jsonEncode({
        'name': 'Renamed',
        'ticker_enabled': false,
        'screens_enabled': false,
      }),
    );
    expect(patch.statusCode, 200);

    final detail = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_enhancement'),
      headers: h.authHeaders,
    );
    expect(detail.statusCode, 200);
    final detailBody = jsonDecode(detail.body) as Map<String, dynamic>;
    expect(detailBody['name'], 'Renamed');
    expect(detailBody['screens_enabled'], isTrue);
    expect(detailBody['ticker_enabled'], isTrue);
    expect(detailBody['theme_id_override'], isNull);
    expect(detailBody['ticker_program_duration_seconds'], isNull);
    expect(detailBody['ticker_pixels_per_second'], isNull);

    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_enhancement'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 200);

    final missing = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_enhancement'),
      headers: h.authHeaders,
    );
    expect(missing.statusCode, 404);
  });

  test('POST base curator configuration round-trips viewport reserve overrides', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final create = await http.post(
      Uri.parse('${h.baseUrl}/v1/curator/configurations'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'test_viewport',
        'name': 'Viewport test',
        'layer': 'base',
        'viewport_reserve_top_pct_override': 15,
        'viewport_reserve_right_pct_override': 8,
      }),
    );
    expect(create.statusCode, 200);

    final detail = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_viewport'),
      headers: h.authHeaders,
    );
    expect(detail.statusCode, 200);
    final detailBody = jsonDecode(detail.body) as Map<String, dynamic>;
    expect(detailBody['viewport_reserve_top_pct_override'], 15);
    expect(detailBody['viewport_reserve_right_pct_override'], 8);
    expect(detailBody['viewport_reserve_bottom_pct_override'], isNull);
  });

  test('POST PATCH base curator ticker overrides clamp and clear to null', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final create = await http.post(
      Uri.parse('${h.baseUrl}/v1/curator/configurations'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'test_ticker_override',
        'name': 'Ticker override',
        'layer': 'base',
        'ticker_program_duration_seconds': 9999,
        'ticker_pixels_per_second': 5,
      }),
    );
    expect(create.statusCode, 200);

    final detail = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_ticker_override'),
      headers: h.authHeaders,
    );
    expect(detail.statusCode, 200);
    final detailBody = jsonDecode(detail.body) as Map<String, dynamic>;
    expect(detailBody['ticker_program_duration_seconds'], 1800);
    expect(detailBody['ticker_pixels_per_second'], 20);

    final clear = await http.patch(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_ticker_override'),
      headers: h.authHeaders,
      body: jsonEncode({
        'ticker_program_duration_seconds': null,
        'ticker_pixels_per_second': null,
      }),
    );
    expect(clear.statusCode, 200);

    final cleared = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_ticker_override'),
      headers: h.authHeaders,
    );
    final clearedBody = jsonDecode(cleared.body) as Map<String, dynamic>;
    expect(clearedBody['ticker_program_duration_seconds'], isNull);
    expect(clearedBody['ticker_pixels_per_second'], isNull);

    await http.delete(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_ticker_override'),
      headers: h.authHeaders,
    );
  });

  test('POST PATCH base curator screens_enabled round-trips', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final create = await http.post(
      Uri.parse('${h.baseUrl}/v1/curator/configurations'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'test_screens_off',
        'name': 'Screens off',
        'layer': 'base',
        'screens_enabled': false,
      }),
    );
    expect(create.statusCode, 200);

    final detail = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_screens_off'),
      headers: h.authHeaders,
    );
    expect(detail.statusCode, 200);
    final detailBody = jsonDecode(detail.body) as Map<String, dynamic>;
    expect(detailBody['screens_enabled'], isFalse);

    final patch = await http.patch(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_screens_off'),
      headers: h.authHeaders,
      body: jsonEncode({'screens_enabled': true}),
    );
    expect(patch.statusCode, 200);

    final updated = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_screens_off'),
      headers: h.authHeaders,
    );
    final updatedBody = jsonDecode(updated.body) as Map<String, dynamic>;
    expect(updatedBody['screens_enabled'], isTrue);

    await http.delete(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_screens_off'),
      headers: h.authHeaders,
    );
  });

  test('POST curator configuration defaults sort_order to 100 when omitted', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final create = await http.post(
      Uri.parse('${h.baseUrl}/v1/curator/configurations'),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'sort_default_test',
        'name': 'Sort default',
        'layer': 'enhancement',
      }),
    );
    expect(create.statusCode, 200);

    final detail = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/sort_default_test'),
      headers: h.authHeaders,
    );
    expect(detail.statusCode, 200);
    final body = jsonDecode(detail.body) as Map<String, dynamic>;
    expect(body['sort_order'], 100);

    await http.delete(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/sort_default_test'),
      headers: h.authHeaders,
    );
  });
}
