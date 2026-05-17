import 'package:test/test.dart';
import 'package:waddle_plugin_sdk/manifest/plugin_manifest.dart';

void main() {
  test('PluginManifest.fromJson parses capabilities', () {
    final m = PluginManifest.fromJson({
      'id': 'waddle_demo',
      'version': '1.0.0',
      'capabilities': ['runtime_signal', 'ticker_source'],
    });
    expect(m.id, 'waddle_demo');
    expect(m.hasCapability('runtime_signal'), isTrue);
  });
}
