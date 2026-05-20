import 'package:test/test.dart';
import 'package:waddle_plugin_sdk/contracts/alert_contract.dart';
import 'package:waddle_plugin_sdk/contracts/collect_contract.dart';
import 'package:waddle_plugin_sdk/contracts/overlay_contract.dart';
import 'package:waddle_plugin_sdk/contracts/screen_contract.dart';
import 'package:waddle_plugin_sdk/contracts/signal_contract.dart';
import 'package:waddle_plugin_sdk/contracts/ticker_contract.dart';

void main() {
  test('CollectResponse toJson round-trip', () {
    const res = CollectResponse(configKvPatches: {'k': 'v'});
    expect(res.toJson(), {
      'v': 1,
      'config_kv_patches': {'k': 'v'},
    });
  });

  test('RuntimeSignalUpdate encodes bool and number', () {
    expect(
      RuntimeSignalUpdate.boolValue(true).toJson(),
      {'bool': true},
    );
    expect(
      const RuntimeSignalUpdate(42).toJson(),
      {'number': 42},
    );
    expect(
      const RuntimeSignalUpdate('x').toJson(),
      {'value': 'x'},
    );
  });

  test('PluginTemplateScreenState toJson', () {
    const state = PluginTemplateScreenState(
      title: 'Hello',
      body: 'World',
      metrics: [
        {'label': 'Temp', 'value': '72F'},
      ],
    );
    expect(state.toJson(), {
      'v': 1,
      'title': 'Hello',
      'body': 'World',
      'metrics': [
        {'label': 'Temp', 'value': '72F'},
      ],
    });
  });

  test('TickerItemsResponse toJson', () {
    const res = TickerItemsResponse(
      items: [
        TickerItemDto(body: 'Line 1'),
      ],
    );
    final json = res.toJson();
    expect(json['v'], 1);
    expect(json['items'], hasLength(1));
  });

  test('AlertCreateRequest toJson', () {
    const alert = AlertCreateRequest(
      title: 'Ping',
      body: 'Hello',
      severity: AlertSeverity.info,
    );
    final json = alert.toJson();
    expect(json['title'], 'Ping');
    expect(json['severity'], 'info');
  });

  test('PluginTemplateOverlayState toJson', () {
    const overlay = PluginTemplateOverlayState(opacity: 0.5);
    expect(overlay.toJson()['opacity'], 0.5);
  });
}
