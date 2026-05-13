import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_display/alerts/drift_alert_repository.dart';
import 'package:waddle_display/api/deployment_api_key_source.dart';
import 'package:waddle_display/api/local_rest_server.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_display/ticker/memory_ticker_curated_repository.dart';
import 'helpers/memory_database.dart';

void main() {
  test('POST and DELETE alerts', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
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
      final post = await http.post(
        Uri.parse('${server.baseUrl}/v1/alerts'),
        headers: {'x-api-key': 'k', 'content-type': 'application/json'},
        body: '{"title":"a","body":"b","priority":2}',
      );
      expect(post.statusCode, 200);
      final id = (jsonDecode(post.body) as Map<String, dynamic>)['id'] as int;
      final list = await http.get(
        Uri.parse('${server.baseUrl}/v1/alerts'),
        headers: {'x-api-key': 'k'},
      );
      expect(list.statusCode, 200);
      final del = await http.delete(
        Uri.parse('${server.baseUrl}/v1/alerts/$id'),
        headers: {'x-api-key': 'k'},
      );
      expect(del.statusCode, 200);
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
