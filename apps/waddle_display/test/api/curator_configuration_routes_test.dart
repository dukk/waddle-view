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

    final detail = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/evening'),
      headers: h.authHeaders,
    );
    expect(detail.statusCode, 200);
    final detailBody = jsonDecode(detail.body) as Map<String, dynamic>;
    expect(detailBody['id'], 'evening');
    expect(detailBody['members'], isA<Map>());
    expect(detailBody['rules'], isA<List>());
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
        'rules': [
          {
            'id': 'r1',
            'priority': 1,
            'start_month': 12,
            'start_day': 25,
            'repeat_annually': true,
          },
        ],
        'members': {
          'screens': [],
          'ticker_tapes': [],
          'overlays': ['overlay_confetti'],
        },
      }),
    );
    expect(create.statusCode, 200);

    final patch = await http.patch(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_enhancement'),
      headers: h.authHeaders,
      body: jsonEncode({'name': 'Renamed'}),
    );
    expect(patch.statusCode, 200);

    final detail = await http.get(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/test_enhancement'),
      headers: h.authHeaders,
    );
    expect(detail.statusCode, 200);
    expect(
      (jsonDecode(detail.body) as Map<String, dynamic>)['name'],
      'Renamed',
    );

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
}
