import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/display_remote_view.dart';
import 'package:waddle_shared/config/display_operator_settings.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/memory_database.dart';

void main() {
  group('displayRemoteViewConfigFromKv', () {
    test('defaults when KV empty', () {
      final config = displayRemoteViewConfigFromKv({});
      expect(config.enabled, isFalse);
      expect(config.host, kDefaultDisplayRemoteViewHost);
      expect(config.port, kDefaultDisplayRemoteViewPort);
      expect(config.path, kDefaultDisplayRemoteViewPath);
      expect(config.configured, isFalse);
    });

    test('configured when enabled with valid host and port', () {
      final config = displayRemoteViewConfigFromKv({
        kDisplayRemoteViewEnabledKvKey: 'true',
        kDisplayRemoteViewHostKvKey: '10.0.0.5',
        kDisplayRemoteViewPortKvKey: '6080',
        kDisplayRemoteViewPathKvKey: '/websockify',
      });
      expect(config.configured, isTrue);
      expect(config.normalizedPath, '/websockify');
      expect(
        config.upstreamWebsocketUri.toString(),
        'ws://10.0.0.5:6080/websockify',
      );
    });

    test('env defaults apply when KV unset', () {
      DisplayRemoteViewEnvDefaults.enabled = true;
      DisplayRemoteViewEnvDefaults.host = '192.168.1.10';
      DisplayRemoteViewEnvDefaults.port = 5901;
      DisplayRemoteViewEnvDefaults.path = '/vnc';
      addTearDown(() {
        DisplayRemoteViewEnvDefaults.enabled = null;
        DisplayRemoteViewEnvDefaults.host = null;
        DisplayRemoteViewEnvDefaults.port = null;
        DisplayRemoteViewEnvDefaults.path = null;
      });
      final config = displayRemoteViewConfigFromKv({});
      expect(config.enabled, isTrue);
      expect(config.host, '192.168.1.10');
      expect(config.port, 5901);
      expect(config.path, '/vnc');
      expect(config.configured, isTrue);
    });
  });

  test('applyDisplayOperatorSettingsPut round-trips remote view fields', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);

    final touched = await applyDisplayOperatorSettingsPut(db, {
      'display_remote_view_enabled': true,
      'display_remote_view_host': 'pi.local',
      'display_remote_view_port': 6081,
      'display_remote_view_path': 'websockify',
    });
    expect(touched, isTrue);

    final body = await readDisplayOperatorSettings(db);
    expect(body['display_remote_view_enabled'], isTrue);
    expect(body['display_remote_view_host'], 'pi.local');
    expect(body['display_remote_view_port'], 6081);
    expect(body['display_remote_view_path'], '/websockify');
  });

  test('readDisplayOperatorSettings reports password configured', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final secrets = InMemorySecretStore();
    await secrets.write(kDisplayRemoteViewVncPasswordSecretKey, 'secret');

    final body = await readDisplayOperatorSettings(db, secrets: secrets);
    expect(body['display_remote_view_password_configured'], isTrue);
  });
}
