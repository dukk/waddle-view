import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_qr_code_settings.dart';
import 'package:waddle_shared/persistence/qr_overlay_payload.dart';

void main() {
  test('parse defaults when empty', () {
    expect(QrCodeOverlaySettings.parse(''), QrCodeOverlaySettings.defaults);
  });

  test('parse placement title description and payload from template', () {
    final s = QrCodeOverlaySettings.parseMap({
      'template': kQrOverlayTemplateHttp,
      'template_fields': {'url': 'https://waddle.example'},
      'title': 'Visit',
      'description': 'Scan me',
      'x': 0.1,
      'y': 0.2,
      'scale': 0.25,
    });
    expect(s.payload, 'https://waddle.example');
    expect(s.title, 'Visit');
    expect(s.description, 'Scan me');
    expect(s.placement.x, 0.1);
    expect(s.placement.scale, 0.25);
    expect(s.isRenderable, isTrue);
  });

  test('normalize rebuilds payload from template_fields', () {
    final norm = normalizeQrCodeOverlayConfigJsonString(
      '{"template":"wifi","template_fields":{"ssid":"Guest","securityType":"WPA","password":"x"},'
      '"title":"WiFi","x":0.82,"y":0.78,"scale":0.22}',
    );
    expect(norm, isNotNull);
    final parsed = QrCodeOverlaySettings.parse(norm!);
    expect(parsed.payload, 'WIFI:T:WPA;S:Guest;P:x;');
    expect(parsed.title, 'WiFi');
    expect(parsed.template, kQrOverlayTemplateWifi);
  });

  test('normalize rejects empty payload', () {
    expect(
      normalizeQrCodeOverlayConfigJsonString('{"template":"http","template_fields":{}}'),
      isNull,
    );
    expect(normalizeQrCodeOverlayConfigJsonString('{}'), isNull);
    expect(
      normalizeQrCodeOverlayConfigJsonString('{"template":"invalid"}'),
      isNull,
    );
  });

  test('normalize strips enabled and messages', () {
    final norm = normalizeQrCodeOverlayConfigJsonString(
      '{"enabled":true,"messages":["x"],"template":"custom","payload":"data","x":0.5}',
    );
    expect(norm, isNotNull);
    final parsed = QrCodeOverlaySettings.parse(norm!);
    expect(parsed.payload, 'data');
    expect(parsed.placement.x, 0.5);
  });
}
