import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';

import '../helpers/memory_database.dart';
import '../helpers/rest_auth_helper.dart';

void main() {
  test('GET integration kv lists keys with optional prefix', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedStubIntegrationForTest(db);
    final kv = IntegrationKvRepository(db);
    await kv.upsertIntegration(
      integrationId: 'stub',
      key: 'collect.last_ms',
      value: '100',
      valueType: kIntegrationKvTypeIntMs,
    );
    await kv.upsertIntegration(
      integrationId: 'stub',
      key: 'collect.other',
      value: 'x',
    );

    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final all = await http.get(
      Uri.parse('${h.baseUrl}/v1/integrations/stub/kv'),
      headers: h.authHeaders,
    );
    expect(all.statusCode, 200);
    final items = (jsonDecode(all.body) as Map)['items'] as List;
    expect(items.length, 2);

    final filtered = await http.get(
      Uri.parse('${h.baseUrl}/v1/integrations/stub/kv?prefix=collect.last'),
      headers: h.authHeaders,
    );
    expect(filtered.statusCode, 200);
    final filteredItems = (jsonDecode(filtered.body) as Map)['items'] as List;
    expect(filteredItems.length, 1);
    expect(filteredItems.first['key'], 'collect.last_ms');
  });

  test('GET and DELETE single integration kv key', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedStubIntegrationForTest(db);
    await IntegrationKvRepository(db).upsertIntegration(
      integrationId: 'stub',
      key: 'probe',
      value: '{"ok":true}',
      valueType: kIntegrationKvTypeJson,
    );

    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = '${h.baseUrl}/v1/integrations/stub/kv/probe';

    final get = await http.get(Uri.parse(base), headers: h.authHeaders);
    expect(get.statusCode, 200);
    final body = jsonDecode(get.body) as Map<String, dynamic>;
    expect(body['value'], '{"ok":true}');

    final missing = await http.get(
      Uri.parse('${h.baseUrl}/v1/integrations/stub/kv/missing'),
      headers: h.authHeaders,
    );
    expect(missing.statusCode, 404);

    final del = await http.delete(Uri.parse(base), headers: h.authHeaders);
    expect(del.statusCode, 200);

    final after = await http.get(Uri.parse(base), headers: h.authHeaders);
    expect(after.statusCode, 404);
  });

  test('kv routes return 404 for unknown integration', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/integrations/no_such/kv'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 404);
  });
}
