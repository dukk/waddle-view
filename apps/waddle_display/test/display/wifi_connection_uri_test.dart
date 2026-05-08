import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/guest_wifi/wifi_connection_uri.dart';

void main() {
  group('parseWifiConnectionUri', () {
    test('parses WPA example with H field', () {
      final r = parseWifiConnectionUri(
        'WIFI:T:WPA;S:MyGuest;P:secret;H:false;;',
      );
      expect(r.isValid, isTrue);
      expect(r.ssid, 'MyGuest');
      expect(r.securityType, 'WPA');
      expect(r.password, 'secret');
      expect(r.hidden, isFalse);
      expect(r.rawForQr, 'WIFI:T:WPA;S:MyGuest;P:secret;H:false;;');
    });

    test('parses nopass open network', () {
      final r = parseWifiConnectionUri('WIFI:T:nopass;S:OpenNet;;');
      expect(r.isValid, isTrue);
      expect(r.ssid, 'OpenNet');
      expect(r.securityType, 'nopass');
      expect(r.password, isNull);
      expect(r.hidden, isFalse);
    });

    test('defaults hidden to false when absent', () {
      final r = parseWifiConnectionUri('WIFI:T:WPA2;S:x;P:y;;');
      expect(r.isValid, isTrue);
      expect(r.hidden, isFalse);
    });

    test('parses H true', () {
      final r = parseWifiConnectionUri('WIFI:T:WPA3;S:Hi;P:p;H:true;;');
      expect(r.isValid, isTrue);
      expect(r.hidden, isTrue);
    });

    test('unescapes semicolon in SSID', () {
      final r = parseWifiConnectionUri(r'WIFI:T:WPA;S:semi\;ssid;P:p;;');
      expect(r.isValid, isTrue);
      expect(r.ssid, 'semi;ssid');
    });

    test('invalid for null and blank', () {
      expect(parseWifiConnectionUri(null).isValid, isFalse);
      expect(parseWifiConnectionUri('').isValid, isFalse);
      expect(parseWifiConnectionUri('   ').isValid, isFalse);
    });

    test('invalid when not WIFI scheme', () {
      expect(parseWifiConnectionUri('http://x').isValid, isFalse);
      expect(parseWifiConnectionUri('WIFI').isValid, isFalse);
    });

    test('invalid without SSID', () {
      expect(parseWifiConnectionUri('WIFI:T:WPA;P:x;;').isValid, isFalse);
    });
  });
}
