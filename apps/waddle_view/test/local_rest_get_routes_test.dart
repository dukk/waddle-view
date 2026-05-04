import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_view/alerts/drift_alert_repository.dart';
import 'package:waddle_view/api/deployment_api_key_source.dart';
import 'package:waddle_view/api/local_rest_server.dart';
import 'package:waddle_view/persistence/database.dart';

import 'helpers/memory_database.dart';

void main() {
  test('GET ticker screens and alerts list', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.tickerScreens).insert(
          TickerScreensCompanion.insert(id: 'a'),
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
    final handler = buildRootHandler(db: db, alerts: alerts, keys: keys);
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final ts = await http.get(
        Uri.parse('${server.baseUrl}/v1/ticker/screens'),
        headers: {'x-api-key': 'k'},
      );
      expect(ts.statusCode, 200);
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
}
