import 'dart:async';
import 'dart:io';

import '../lib/demo_plugin.dart';
import 'package:waddle_plugin_sdk/waddle_plugin_sdk.dart';

Future<void> main(List<String> args) async {
  final dir = Directory.current.path;
  final manifest = await PluginManifest.loadDirectory(dir);
  final demo = DemoPlugin();
  final client = DisplayClient(
    DisplayClientConfig(
      baseUrl: Platform.environment['WADDLE_DISPLAY_BASE_URL'] ??
          'http://127.0.0.1:8787',
      bearerToken: Platform.environment['WADDLE_DISPLAY_API_KEY'],
      pluginId: manifest.id,
    ),
  );

  final server = await runPluginSidecar(
    manifest: manifest,
    handlers: PluginSidecarHandlers(
      onCollect: () {
        final res = demo.collect();
        unawaited(client.putBoolSignal(SignalIds.motionDetected, demo.motionDetected));
        return res;
      },
      tickerItems: demo.tickerItems,
      screenState: demo.screenState,
      overlayState: demo.overlayState,
    ),
  );

  // ignore: avoid_print
  print('waddle_demo sidecar on port ${server.port}');
}
