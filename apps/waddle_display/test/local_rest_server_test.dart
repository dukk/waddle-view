import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'package:waddle_display/alerts/drift_alert_repository.dart';
import 'package:waddle_display/api/deployment_api_key_source.dart';
import 'package:waddle_display/api/local_rest_server.dart';
import 'package:waddle_display/data/seed/tables/joke_categories_seed.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_display/ticker/memory_ticker_curated_repository.dart';

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
      secrets: InMemorySecretStore(),
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
      secrets: InMemorySecretStore(),
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
}

Future<File> _tempKeyFile(String value) async {
  final dir = await Directory.systemTemp.createTemp('wv_rest_test_');
  final file = File('${dir.path}/waddle_api.key');
  await file.writeAsString('$value\n', flush: true);
  return file;
}
