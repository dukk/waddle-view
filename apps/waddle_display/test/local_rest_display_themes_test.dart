import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/theme/display_theme_kv.dart';

import 'helpers/memory_database.dart';
import 'helpers/rest_auth_helper.dart';

void main() {
  test('POST GET PATCH DELETE display themes CRUD', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final create = await http.post(
      Uri.parse('${h.baseUrl}/v1/display/themes'),
      headers: {...h.authHeaders, 'content-type': 'application/json'},
      body: jsonEncode({
        'label': 'Test Aurora',
        'preview': {
          'display': ['#0D1B2A', '#1B263B'],
          'primaryContainer': ['#E0E1DD', '#1B263B', '#415A77'],
          'secondaryContainer': ['#E0E1DD', '#415A77', '#778DA9'],
          'accents': ['#83AF84', '#E05C6C', '#FFE356', '#966CB3'],
        },
      }),
    );
    expect(create.statusCode, 200);
    final created = jsonDecode(create.body) as Map<String, dynamic>;
    final id = '${created['id']}';
    expect(id, startsWith('custom_'));

    final list = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/themes'),
      headers: h.authHeaders,
    );
    expect(list.statusCode, 200);
    final items =
        (jsonDecode(list.body) as Map<String, dynamic>)['items'] as List<dynamic>;
    expect(items.any((e) => (e as Map)['id'] == id), isTrue);

    final patch = await http.patch(
      Uri.parse('${h.baseUrl}/v1/display/themes/$id'),
      headers: {...h.authHeaders, 'content-type': 'application/json'},
      body: jsonEncode({'label': 'Aurora Renamed'}),
    );
    expect(patch.statusCode, 200);
    expect((jsonDecode(patch.body) as Map)['label'], 'Aurora Renamed');

    await http.put(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: {...h.authHeaders, 'content-type': 'application/json'},
      body: jsonEncode({'display_theme_id': id}),
    );

    final settings = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: h.authHeaders,
    );
    expect((jsonDecode(settings.body) as Map)['display_theme_id'], id);

    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/display/themes/$id'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 200);

    final settingsAfter = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: h.authHeaders,
    );
    expect(
      (jsonDecode(settingsAfter.body) as Map)['display_theme_id'],
      kDefaultDisplayThemeId,
    );
  });

  test('PUT display settings rejects unknown theme id', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final put = await http.put(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: {...h.authHeaders, 'content-type': 'application/json'},
      body: jsonEncode({'display_theme_id': 'not_a_real_theme'}),
    );
    expect(put.statusCode, 400);
    expect(jsonDecode(put.body), {'error': 'unknown_display_theme_id'});
  });
}
