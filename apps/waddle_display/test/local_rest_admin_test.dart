import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/alerts/drift_alert_repository.dart';
import 'package:waddle_display/api/deployment_api_key_source.dart';
import 'package:waddle_display/api/local_rest_server.dart';
import 'package:waddle_display/persistence/database.dart';
import 'package:waddle_display/persistence/tables.dart';
import 'package:waddle_display/secrets/in_memory_secret_store.dart';
import 'package:waddle_display/ticker/memory_ticker_curated_repository.dart';

import 'helpers/memory_database.dart';

void main() {
  test('forces password rotation and disables setup screen', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: kAdminBootstrapDoneKvKey,
            value: '0',
          ),
        );
    await db.into(db.screenDefinitions).insert(
          ScreenDefinitionsCompanion.insert(
            id: 'admin_setup',
            name: 'Setup',
            screenType: 'admin_setup',
          ),
        );
    final keyFile = await _tempKeyFile('install-password');
    final ticker = MemoryTickerCuratedRepository();
    addTearDown(ticker.dispose);
    final handler = buildRootHandler(
      db: db,
      alerts: DriftAlertRepository(db),
      keys: FakeDeploymentApiKeySource('install-password'),
      ticker: ticker,
      secrets: InMemorySecretStore(),
      onConfigChanged: () async {},
      keyFile: keyFile,
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    try {
      final login = await http.post(
        Uri.parse('${server.baseUrl}/admin/login'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: 'password=install-password',
      );
      expect(login.statusCode, 302);
      final cookie = login.headers['set-cookie'];
      expect(cookie, isA<String>());

      final changePage = await http.get(
        Uri.parse('${server.baseUrl}/admin/change-password'),
        headers: {'cookie': cookie!},
      );
      expect(changePage.statusCode, 200);
      final csrf = RegExp(r'name="csrf" value="([^"]+)"')
          .firstMatch(changePage.body)!
          .group(1)!;

      final changed = await http.post(
        Uri.parse('${server.baseUrl}/admin/change-password'),
        headers: {
          'cookie': cookie,
          'content-type': 'application/x-www-form-urlencoded',
        },
        body:
            'csrf=$csrf&password=new-password-12345&confirm_password=new-password-12345',
      );
      expect(changed.statusCode, 302);

      final keyRaw = await keyFile.readAsString();
      expect(keyRaw.trim(), 'new-password-12345');

      final bootstrap = await (db.select(db.configKeyValues)
            ..where((t) => t.key.equals(kAdminBootstrapDoneKvKey)))
          .getSingle();
      expect(bootstrap.value, '1');
      final setupRow = await (db.select(db.screenDefinitions)
            ..where((t) => t.id.equals('admin_setup')))
          .getSingle();
      expect(setupRow.enabled, false);
    } finally {
      await server.close();
      await db.close();
    }
  });
}

Future<File> _tempKeyFile(String value) async {
  final dir = await Directory.systemTemp.createTemp('wv_admin_test_');
  final file = File('${dir.path}/waddle_api.key');
  await file.writeAsString('$value\n', flush: true);
  return file;
}
