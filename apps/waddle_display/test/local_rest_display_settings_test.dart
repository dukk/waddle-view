import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/controller_datetime_format_kv.dart';
import 'helpers/memory_database.dart';
import 'helpers/rest_auth_helper.dart';

void main() {
  test('GET display settings includes datetime format defaults', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['controller_time_format'], kDefaultControllerTimeFormat);
    expect(body['controller_date_order'], kDefaultControllerDateOrder);
    expect(body['display_theme_id'], isNotEmpty);
    expect(body['display_timezone'], isNotEmpty);
    expect(body.containsKey('adoption_allowed_roles'), isTrue);
    expect(body['display_viewport_reserve_top_pct'], 0);
    expect(body.containsKey('display_image_overlay'), isFalse);
  });

  test('PUT display settings round-trips datetime format and theme', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final put = await http.put(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: h.authHeaders,
      body: jsonEncode({
        'controller_time_format': '24h',
        'controller_date_order': 'dmy',
        'display_theme_id': 'graphite_amber',
      }),
    );
    expect(put.statusCode, 200);

    final get = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: h.authHeaders,
    );
    expect(get.statusCode, 200);
    final body = jsonDecode(get.body) as Map<String, dynamic>;
    expect(body['controller_time_format'], kControllerTimeFormat24h);
    expect(body['controller_date_order'], kControllerDateOrderDmy);
    expect(body['display_theme_id'], 'graphite_amber');
  });

  test('PUT display settings round-trips viewport reserve pct', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final put = await http.put(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: h.authHeaders,
      body: jsonEncode({
        'display_viewport_reserve_top_pct': 10,
        'display_viewport_reserve_left_pct': 5,
      }),
    );
    expect(put.statusCode, 200);

    final get = await http.get(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: h.authHeaders,
    );
    final body = jsonDecode(get.body) as Map<String, dynamic>;
    expect(body['display_viewport_reserve_top_pct'], 10);
    expect(body['display_viewport_reserve_left_pct'], 5);
  });

  test('PUT display settings empty body returns 400', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final put = await http.put(
      Uri.parse('${h.baseUrl}/v1/display/settings'),
      headers: h.authHeaders,
      body: jsonEncode({}),
    );
    expect(put.statusCode, 400);
    expect(jsonDecode(put.body), {'error': 'no_display_settings_fields'});
  });

}
