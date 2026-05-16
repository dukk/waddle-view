import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';
import '../helpers/rest_auth_helper.dart';

Future<void> _seedCatalogRows(AppDatabase db) async {
  const cat = 'general';
  await db.into(db.contentCategories).insert(
        ContentCategoriesCompanion.insert(id: cat, label: 'General'),
      );
  await db.into(db.jokeCategories).insert(
        JokeCategoriesCompanion.insert(id: cat, label: 'General'),
      );
  await db.into(db.triviaCategories).insert(
        TriviaCategoriesCompanion.insert(id: cat, label: 'General'),
      );
  await db.into(db.rssFeedSources).insert(
        RssFeedSourcesCompanion.insert(id: 'f1', url: 'https://example.com/feed.xml'),
      );
  await db.into(db.jokes).insert(
        JokesCompanion.insert(
          id: 'j1',
          categoryId: cat,
          setup: 'alpha setup',
          punchline: 'beta punch',
          createdAtMs: DateTime.fromMillisecondsSinceEpoch(10),
        ),
      );
  await db.into(db.jokes).insert(
        JokesCompanion.insert(
          id: 'j2',
          categoryId: cat,
          setup: 'other',
          punchline: 'x',
          createdAtMs: DateTime.fromMillisecondsSinceEpoch(20),
          suppressed: const Value(true),
        ),
      );
}

void main() {
  test('GET /v1/catalog/jokes paginates and filters', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedCatalogRows(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final page = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes?limit=1&offset=0&setup=alpha'),
      headers: h.authHeaders,
    );
    expect(page.statusCode, 200);
    final body = jsonDecode(page.body) as Map<String, dynamic>;
    expect(body['total'], 1);
    expect((body['items'] as List).length, 1);
    expect((body['items'] as List).first['id'], 'j1');
    expect((body['items'] as List).first['integration_type'], 'joke_openai');

    final all = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes?limit=50&offset=0'),
      headers: h.authHeaders,
    );
    expect(all.statusCode, 200);
    final allBody = jsonDecode(all.body) as Map<String, dynamic>;
    expect(allBody['total'], 2);

    final suppressed = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes?suppressed=true'),
      headers: h.authHeaders,
    );
    expect(suppressed.statusCode, 200);
    final supBody = jsonDecode(suppressed.body) as Map<String, dynamic>;
    expect(supBody['total'], 1);
    expect((supBody['items'] as List).first['id'], 'j2');
  });

  test('GET /v1/catalog/rss-feeds lists feeds', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedCatalogRows(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/rss-feeds'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect((body['items'] as List).length, 1);
    expect((body['items'] as List).first['id'], 'f1');
  });

  test('GET /v1/catalog/alerts paginates and filters', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.alerts).insert(
          AlertsCompanion.insert(
            title: 'Sign-in',
            body: 'Use code ABC',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
            source: const Value('google_calendar'),
          ),
        );
    await db.into(db.alerts).insert(
          AlertsCompanion.insert(
            title: 'Other',
            body: 'Nothing',
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
          ),
        );
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final page = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/alerts?limit=1&offset=0&title=Sign'),
      headers: h.authHeaders,
    );
    expect(page.statusCode, 200);
    final body = jsonDecode(page.body) as Map<String, dynamic>;
    expect(body['total'], 1);
    expect((body['items'] as List).length, 1);
    expect((body['items'] as List).first['title'], 'Sign-in');

    final all = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/alerts?limit=50&offset=0'),
      headers: h.authHeaders,
    );
    expect(all.statusCode, 200);
    final allBody = jsonDecode(all.body) as Map<String, dynamic>;
    expect(allBody['total'], 2);
  });

  test('viewer cannot read catalog', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedCatalogRows(db);
    final h = await RestTestHarness.start(database: db, role: kUserRoleViewer);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 403);
  });

  test('power_viewer can read catalog without suppressed rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedCatalogRows(db);
    final h = await RestTestHarness.start(database: db, role: kUserRolePowerViewer);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes?limit=50&offset=0'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['total'], 1);
    final items = body['items'] as List;
    expect(items.length, 1);
    expect((items.first as Map)['id'], 'j1');
    expect((items.first as Map).containsKey('suppressed'), isFalse);
  });

  test('power_viewer cannot use suppressed=true on catalog', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedCatalogRows(db);
    final h = await RestTestHarness.start(database: db, role: kUserRolePowerViewer);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes?suppressed=true'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 403);
  });

  test('power_viewer cannot PATCH content suppression', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedCatalogRows(db);
    final h = await RestTestHarness.start(database: db, role: kUserRolePowerViewer);
    addTearDown(h.dispose);

    final res = await http.patch(
      Uri.parse('${h.baseUrl}/v1/content/jokes/j1'),
      headers: h.authHeaders,
      body: '{"suppressed":true}',
    );
    expect(res.statusCode, 403);
  });
}
