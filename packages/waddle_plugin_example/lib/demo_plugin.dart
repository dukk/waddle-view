import 'package:waddle_plugin_sdk/waddle_plugin_sdk.dart';

/// Demo plugin logic toggling motion and publishing ticker/collect payloads.
class DemoPlugin {
  bool motionDetected = false;

  CollectResponse collect() {
    motionDetected = !motionDetected;
    return CollectResponse(
      configKvPatches: {
        'ticker.marquee.waddle_demo': motionDetected
            ? 'Demo plugin: motion detected'
            : 'Demo plugin: no motion',
      },
    );
  }

  TickerItemsResponse tickerItems() => TickerItemsResponse(
        items: [
          TickerItemDto(
            body: motionDetected
                ? 'Waddle demo: room active'
                : 'Waddle demo: standing by',
          ),
        ],
      );

  PluginTemplateScreenState screenState() => PluginTemplateScreenState(
        title: 'Waddle demo',
        body: motionDetected ? 'Motion detected' : 'Idle',
        metrics: [
          {'label': 'Signal', 'value': motionDetected ? 'on' : 'off'},
        ],
      );

  PluginTemplateOverlayState overlayState() => PluginTemplateOverlayState(
        opacity: motionDetected ? 0.25 : 0.1,
        messages: motionDetected ? const ['Hello!'] : const [],
      );

  RuntimeSignalUpdate motionSignal() =>
      RuntimeSignalUpdate.boolValue(motionDetected);

  AlertCreateRequest alarmAlert() => const AlertCreateRequest(
        title: 'Demo alarm',
        body: 'Alarm signal from waddle_demo plugin',
        severity: AlertSeverity.critical,
      );
}
