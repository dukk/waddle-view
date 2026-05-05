import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart';
import 'dart:io';

import 'package:waddle_view/alerts/drift_alert_repository.dart';
import 'package:waddle_view/api/deployment_api_key_source.dart';
import 'package:waddle_view/api/local_rest_server.dart';
import 'package:waddle_view/curator/ticker_item.dart';
import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/secrets/in_memory_secret_store.dart';
import 'package:waddle_view/ticker/memory_ticker_curated_repository.dart';

import 'helpers/memory_database.dart';

void main() {
  test('GET screens and alerts list', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.screenDefinitions).insert(
          ScreenDefinitionsCompanion.insert(
            id: 'a',
            name: 'Screen A',
            minPlacementsPerProgram: const Value(1),
            maxPlacementsPerProgram: const Value(3),
            dataKey: const Value('shared_news'),
          ),
        );
    await db.into(db.curatorDataKeyProgramLimits).insert(
          CuratorDataKeyProgramLimitsCompanion.insert(
            dataKey: 'shared_news',
            minPlacementsPerProgram: const Value(2),
            maxPlacementsPerProgram: const Value(4),
          ),
        );
    await db.into(db.dashboardAlerts).insert(
          DashboardAlertsCompanion.insert(
            title: 't',
            body: 'b',
            createdAt: 1,
          ),
        );
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      secrets: InMemorySecretStore(),
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final ts = await http.get(
        Uri.parse('${server.baseUrl}/v1/screens'),
        headers: {'x-api-key': 'k'},
      );
      expect(ts.statusCode, 200);
      expect(ts.body, contains('"id":"a"'));
      expect(ts.body, contains('"min_placements_per_program":1'));
      expect(ts.body, contains('"max_placements_per_program":3'));
      expect(ts.body, contains('"data_key":"shared_news"'));
      expect(ts.body, contains('"data_key_min_placements_per_program":2'));
      expect(ts.body, contains('"data_key_max_placements_per_program":4'));
      final al = await http.get(
        Uri.parse('${server.baseUrl}/v1/alerts'),
        headers: {'x-api-key': 'k'},
      );
      expect(al.statusCode, 200);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('GET ticker items returns ordered bodies from memory repo', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    await ticker.replaceAll([
      const TickerItem(kind: 'time', body: '12:00:00'),
      const TickerItem(kind: 'news', body: 'N'),
    ]);
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('k');
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: ticker,
      secrets: InMemorySecretStore(),
      onConfigChanged: () async {},
      keyFile: await _tempKeyFile('k'),
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final res = await http.get(
        Uri.parse('${server.baseUrl}/v1/ticker/items'),
        headers: {'x-api-key': 'k'},
      );
      expect(res.statusCode, 200);
      expect(res.body, contains('"body":"12:00:00"'));
      expect(res.body, contains('"ordinal":0'));
      expect(res.body, contains('"ordinal":1'));
      expect(res.body, isNot(contains('source')));
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
