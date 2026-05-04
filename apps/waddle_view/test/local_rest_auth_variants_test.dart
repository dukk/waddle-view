import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_view/alerts/drift_alert_repository.dart';
import 'package:waddle_view/api/deployment_api_key_source.dart';
import 'package:waddle_view/api/local_rest_server.dart';
import 'package:waddle_view/persistence/database.dart';

import 'helpers/memory_database.dart';

void main() {
  test('503 when key file empty and bearer auth', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource(null);
    final handler = buildRootHandler(db: db, alerts: alerts, keys: keys);
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final r = await http.get(
        Uri.parse('${server.baseUrl}/v1/providers'),
        headers: {'x-api-key': 'x'},
      );
      expect(r.statusCode, 503);
    } finally {
      await server.close();
      await db.close();
    }
  });

  test('accepts Authorization bearer', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(id: 'a', providerType: 'b'),
        );
    final alerts = DriftAlertRepository(db);
    final keys = FakeDeploymentApiKeySource('secret');
    final handler = buildRootHandler(db: db, alerts: alerts, keys: keys);
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final r = await http.get(
        Uri.parse('${server.baseUrl}/v1/providers'),
        headers: {'Authorization': 'Bearer secret'},
      );
      expect(r.statusCode, 200);
    } finally {
      await server.close();
      await db.close();
    }
  });
}
