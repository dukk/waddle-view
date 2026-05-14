import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_display/alerts/drift_alert_repository.dart';
import 'package:waddle_display/api/deployment_api_key_source.dart';
import 'package:waddle_display/api/local_rest_server.dart';
import 'package:waddle_display/data/seed/tables/joke_categories_seed.dart';
import 'package:waddle_display/ticker/memory_ticker_curated_repository.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import 'helpers/memory_database.dart';

void main() {
  test('health is public; providers require API key', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(id: 'x', providerType: 'y'),
        );
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('supersecret');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('supersecret'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final health = await http.get(
        Uri.parse('${server.baseUrl}/v1/health'),
      );
      expect(health.statusCode, 200);

      final denied = await http.get(
        Uri.parse('${server.baseUrl}/v1/providers'),
      );
      expect(denied.statusCode, 401);

      final ok = await http.get(
        Uri.parse('${server.baseUrl}/v1/providers'),
        headers: {'x-api-key': 'supersecret'},
      );
      expect(ok.statusCode, 200);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('PATCH content suppression updates row', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);

    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 'rest_j1',
            categoryId: 'dad',
            setup: 'x',
            punchline: 'y',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('supersecret');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('supersecret'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final uri = Uri.parse('${server.baseUrl}/v1/content/jokes/rest_j1');
      final res = await http.patch(
        uri,
        headers: {
          'x-api-key': 'supersecret',
          'content-type': 'application/json',
        },
        body: '{"suppressed":true}',
      );
      expect(res.statusCode, 200);
      final row = await (db.select(db.jokes)
            ..where((t) => t.id.equals('rest_j1')))
          .getSingle();
      expect(row.suppressed, isTrue);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test(
    '/v1/reject-terms supports list, upsert, delete, format, and rescan',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      await ensureDefaultJokeCategories(db);

      // Seed an RSS article whose title contains a future block term so the
      // rescan endpoint marks it suppressed after we add the term.
      await db.into(db.rssFeedSources).insert(
            RssFeedSourcesCompanion.insert(
              id: 'feed1',
              url: 'https://example.test/rss',
            ),
          );
      await db.into(db.rssArticles).insert(
            RssArticlesCompanion.insert(
              id: 'rest_a1',
              feedId: 'feed1',
              guid: 'g1',
              title: 'Cuss is here',
              link: 'https://x.test',
              publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
              fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          );

      // Clear the default reject terms so we can drive the behavior cleanly.
      await db.delete(db.rejectTerms).go();

      final alerts = DriftAlertRepository(db);
      final keys = FakeDeploymentApiKeySource('supersecret');
      final ticker = MemoryTickerCuratedRepository();
      addTearDown(ticker.dispose);
      final handler = buildRootHandler(
        db: db,
        alerts: alerts,
        keys: keys,
        ticker: ticker,
        onConfigChanged: () async {},
        keyFile: await _tempKeyFile('supersecret'),
        setupScreenId: 'admin_setup',
      );
      final server = await LocalRestServer.bind(handler: handler, port: 0);
      try {
        final base = '${server.baseUrl}/v1/reject-terms';
        final auth = {'x-api-key': 'supersecret'};

        // Initial GET returns empty list and the default censor format.
        final initial = await http.get(Uri.parse(base), headers: auth);
        expect(initial.statusCode, 200);
        final initialBody =
            jsonDecode(initial.body) as Map<String, dynamic>;
        expect(initialBody['items'], isEmpty);
        expect(
          initialBody['censor_format'],
          kRejectCensorFormatAsterisksFull,
        );

        // POST a block term.
        final created = await http.post(
          Uri.parse(base),
          headers: {...auth, 'content-type': 'application/json'},
          body: '{"term":"Cuss","action":"block"}',
        );
        expect(created.statusCode, 200);
        final createdBody =
            jsonDecode(created.body) as Map<String, dynamic>;
        expect(createdBody['term'], 'cuss');
        expect(createdBody['action'], 'block');
        final createdId = createdBody['id'] as String;
        expect(createdId, isNotEmpty);

        // The POST kicks off a rescan; wait until the row is suppressed.
        var marked = false;
        for (var attempt = 0; attempt < 50 && !marked; attempt++) {
          final row = await (db.select(db.rssArticles)
                ..where((t) => t.id.equals('rest_a1')))
              .getSingle();
          if (row.suppressed) {
            marked = true;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(marked, isTrue,
            reason: 'rescan should suppress matching article');

        // Invalid action returns 400.
        final invalid = await http.post(
          Uri.parse(base),
          headers: {...auth, 'content-type': 'application/json'},
          body: '{"term":"hello","action":"banana"}',
        );
        expect(invalid.statusCode, 400);

        // PATCH updates the action in place.
        final patched = await http.patch(
          Uri.parse('$base/$createdId'),
          headers: {...auth, 'content-type': 'application/json'},
          body: '{"term":"Cuss","action":"censor"}',
        );
        expect(patched.statusCode, 200);
        final patchedRow = await (db.select(db.rejectTerms)
              ..where((t) => t.id.equals(createdId)))
            .getSingle();
        expect(patchedRow.action, kRejectTermActionCensor);

        // PUT the censor format.
        final fmt = await http.put(
          Uri.parse('$base/format'),
          headers: {...auth, 'content-type': 'application/json'},
          body: '{"format":"bracketed_token"}',
        );
        expect(fmt.statusCode, 200);
        final fmtRow = await (db.select(db.configKeyValues)
              ..where((t) => t.key.equals(kRejectCensorFormatKvKey)))
            .getSingle();
        expect(fmtRow.value, kRejectCensorFormatBracketedToken);

        // Unknown format rejected.
        final badFmt = await http.put(
          Uri.parse('$base/format'),
          headers: {...auth, 'content-type': 'application/json'},
          body: '{"format":"crayons"}',
        );
        expect(badFmt.statusCode, 400);

        // POST rescan returns counts (article already suppressed so 0 marked).
        final rescan = await http.post(
          Uri.parse('$base/rescan'),
          headers: {...auth, 'content-type': 'application/json'},
          body: '{}',
        );
        expect(rescan.statusCode, 200);
        final rescanBody = jsonDecode(rescan.body) as Map<String, dynamic>;
        expect(rescanBody['total_marked'], 0);

        // DELETE removes the row.
        final del = await http.delete(
          Uri.parse('$base/$createdId'),
          headers: auth,
        );
        expect(del.statusCode, 200);
        final missing = await http.delete(
          Uri.parse('$base/$createdId'),
          headers: auth,
        );
        expect(missing.statusCode, 404);

        final after = await http.get(Uri.parse(base), headers: auth);
        final afterBody = jsonDecode(after.body) as Map<String, dynamic>;
        expect(afterBody['items'], isEmpty);
      } finally {
        await server.close();
        await db.close();
      }
    },
  );
}

Future<File> _tempKeyFile(String value) async {
  final dir = await Directory.systemTemp.createTemp('wv_rest_test_');
  final file = File('${dir.path}/waddle_api.key');
  await file.writeAsString('$value\n', flush: true);
  return file;
}
