import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:waddle_plugin_sdk/contracts/collect_contract.dart';
import 'package:waddle_plugin_sdk/manifest/plugin_manifest.dart';
import 'package:waddle_plugin_sdk/sidecar/sidecar_server.dart';

void main() {
  late HttpServer server;

  tearDown(() async {
    await server.close(force: true);
  });

  test('runPluginSidecar serves health and collect', () async {
    const manifest = PluginManifest(
      id: 'test_plugin',
      version: '1.0.0',
      capabilities: const ['collect'],
    );
    server = await runPluginSidecar(
      manifest: manifest,
      handlers: PluginSidecarHandlers(
        onCollect: () => const CollectResponse(configKvPatches: {'a': '1'}),
        health: () => true,
      ),
      port: 0,
    );

    final base = 'http://${server.address.host}:${server.port}';
    final health = await HttpClient()
        .getUrl(Uri.parse('$base/health'))
        .then((r) => r.close());
    expect(health.statusCode, 200);

    final collectReq = await HttpClient().postUrl(Uri.parse('$base/collect'));
    final collectRes = await collectReq.close();
    expect(collectRes.statusCode, 200);
    final body = await collectRes.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    expect(json['config_kv_patches'], {'a': '1'});
  });

  test('health returns 503 when handler reports unhealthy', () async {
    const manifest = PluginManifest(
      id: 'test_plugin',
      version: '1.0.0',
      capabilities: const [],
    );
    server = await runPluginSidecar(
      manifest: manifest,
      handlers: PluginSidecarHandlers(health: () => false),
      port: 0,
    );

    final base = 'http://${server.address.host}:${server.port}';
    final health = await HttpClient()
        .getUrl(Uri.parse('$base/health'))
        .then((r) => r.close());
    expect(health.statusCode, 503);
  });
}
