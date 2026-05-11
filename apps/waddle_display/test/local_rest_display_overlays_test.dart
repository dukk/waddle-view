import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_display/alerts/drift_alert_repository.dart';
import 'package:waddle_display/api/deployment_api_key_source.dart';
import 'package:waddle_display/api/local_rest_server.dart';
import 'package:waddle_display/persistence/display_overlay_repository.dart';
import 'package:waddle_display/persistence/tables.dart';
import 'package:waddle_display/secrets/in_memory_secret_store.dart';
import 'package:waddle_display/ticker/memory_ticker_curated_repository.dart';

import 'helpers/memory_database.dart';

void main() {
  test('display overlays REST CRUD', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDisplayOverlayTableExists(db);

    final alerts = DriftAlertRepository(db);
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
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
      final post = await http.post(
        Uri.parse('${server.baseUrl}/v1/display/overlays'),
        headers: {'x-api-key': 'k', 'content-type': 'application/json'},
        body: jsonEncode({
          'id': 'x_test_overlay',
          'enabled': true,
          'overlay_kind': kOverlayKindHeartsRain,
          'label': 'Test',
          'messages_json': ['Hi'],
          'repeat_annually': true,
          'start_month': 7,
          'start_day': 4,
        }),
      );
      expect(post.statusCode, 200);

      final listed = await http.get(
        Uri.parse('${server.baseUrl}/v1/display/overlays'),
        headers: {'x-api-key': 'k'},
      );
      expect(listed.statusCode, 200);
      final decoded = jsonDecode(listed.body) as Map<String, dynamic>;
      final items = decoded['items'] as List<Object?>;
      expect(items.length, 1);

      final patch = await http.patch(
        Uri.parse('${server.baseUrl}/v1/display/overlays/x_test_overlay'),
        headers: {'x-api-key': 'k', 'content-type': 'application/json'},
        body: jsonEncode({
          'enabled': false,
        }),
      );
      expect(patch.statusCode, 200);
      final after = await fetchDisplayOverlaySchedules(db);
      expect(after.single.enabled, false);

      final del = await http.delete(
        Uri.parse('${server.baseUrl}/v1/display/overlays/x_test_overlay'),
        headers: {'x-api-key': 'k'},
      );
      expect(del.statusCode, 200);
      final empty = await fetchDisplayOverlaySchedules(db);
      expect(empty, isEmpty);
    } finally {
      await server.close();
      await db.close();
    }
  });
}

Future<File> _tempKeyFile(String value) async {
  final dir = await Directory.systemTemp.createTemp('wv_overlay_rest_');
  final file = File('${dir.path}/waddle_api.key');
  await file.writeAsString('$value\n', flush: true);
  return file;
}
