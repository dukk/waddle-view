import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_view/alerts/drift_alert_repository.dart';
import 'package:waddle_view/api/deployment_api_key_source.dart';
import 'package:waddle_view/api/local_rest_server.dart';
import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/ticker/memory_ticker_curated_repository.dart';

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
}
