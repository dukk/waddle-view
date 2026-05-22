import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:waddle_plugin_sdk/manifest/plugin_manifest.dart';

void main() {
  test('PluginManifest.fromJson parses capabilities and nested sections', () {
    final manifest = PluginManifest.fromJson({
      'id': 'demo_plugin',
      'version': '1.2.3',
      'min_display_version': '0.9.0',
      'capabilities': ['Collector', 'SCREEN'],
      'integrations': [
        {'id': 'demo_int', 'provider_type': 'plugin_http'},
      ],
      'screen_types': [
        {'type': 'demo_screen'},
      ],
      'ticker_sources': [
        {'type': 'demo_ticker'},
      ],
      'overlays': [
        {
          'overlay_type': 'demo_overlay',
          'layer': 'effect',
          'renderer': 'plugin_template',
        },
      ],
      'runtime_signals': [
        {'predicate_id': 'demo_signal'},
      ],
      'sidecar': {'executable': 'dart run sidecar.dart', 'port': 9090},
    });

    expect(manifest.id, 'demo_plugin');
    expect(manifest.version, '1.2.3');
    expect(manifest.minDisplayVersion, '0.9.0');
    expect(manifest.hasCapability('collector'), isTrue);
    expect(manifest.hasCapability('missing'), isFalse);
    expect(manifest.integrations.single.id, 'demo_int');
    expect(manifest.screenTypes.single.type, 'demo_screen');
    expect(manifest.tickerSources.single.type, 'demo_ticker');
    expect(manifest.overlays.single.overlayType, 'demo_overlay');
    expect(manifest.runtimeSignals.single.predicateId, 'demo_signal');
    expect(manifest.sidecar?.executable, 'dart run sidecar.dart');
    expect(manifest.sidecar?.port, 9090);
  });

  test('PluginManifest.fromJson requires id', () {
    expect(
      () => PluginManifest.fromJson({'version': '1'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('PluginManifest.loadDirectory reads manifest.json', () async {
    final dir = await Directory.systemTemp.createTemp('waddle_plugin_manifest_');
    addTearDown(() => dir.deleteSync(recursive: true));
    await File('${dir.path}/manifest.json').writeAsString(
      jsonEncode({
        'id': 'temp_plugin',
        'version': '0.1.0',
        'capabilities': [],
      }),
    );
    final loaded = await PluginManifest.loadDirectory(dir.path);
    expect(loaded.id, 'temp_plugin');
  });
}
