import 'package:test/test.dart';
import 'package:waddle_shared/persistence/qr_overlay_payload.dart';

void main() {
  test('http adds https when scheme missing', () {
    expect(
      buildQrOverlayPayload(kQrOverlayTemplateHttp, {'url': 'example.com'}),
      'https://example.com',
    );
    expect(
      buildQrOverlayPayload(
        kQrOverlayTemplateHttp,
        {'url': 'http://example.com/path'},
      ),
      'http://example.com/path',
    );
  });

  test('mailto encodes subject and body', () {
    expect(
      buildQrOverlayPayload(kQrOverlayTemplateMailto, {
        'email': 'user@example.com',
        'subject': 'Hello',
        'body': 'World',
      }),
      'mailto:user@example.com?subject=Hello&body=World',
    );
  });

  test('tel and sms payloads', () {
    expect(
      buildQrOverlayPayload(kQrOverlayTemplateTel, {'phone': '+1 555 123 4567'}),
      'tel:+15551234567',
    );
    expect(
      buildQrOverlayPayload(kQrOverlayTemplateSms, {
        'phone': '5551234567',
        'body': 'Hi',
      }),
      'smsto:5551234567?body=Hi',
    );
  });

  test('geo with optional label', () {
    expect(
      buildQrOverlayPayload(kQrOverlayTemplateGeo, {
        'lat': '37.7749',
        'lng': '-122.4194',
      }),
      'geo:37.7749,-122.4194',
    );
    expect(
      buildQrOverlayPayload(kQrOverlayTemplateGeo, {
        'lat': '37.7749',
        'lng': '-122.4194',
        'label': 'SF',
      }),
      'geo:37.7749,-122.4194?q=SF',
    );
  });

  test('wifi matches ZXing-style payload', () {
    expect(
      buildQrOverlayPayload(kQrOverlayTemplateWifi, {
        'ssid': 'My Network',
        'securityType': 'WPA',
        'password': 'secret',
        'hidden': true,
      }),
      'WIFI:T:WPA;S:My Network;P:secret;H:true;',
    );
    expect(
      buildQrOverlayPayload(kQrOverlayTemplateWifi, {
        'ssid': 'Open',
        'securityType': 'nopass',
      }),
      'WIFI:T:nopass;S:Open;',
    );
  });

  test('vcard and vcalendar', () {
    final vcard = buildQrOverlayPayload(kQrOverlayTemplateVcard, {
      'fullName': 'Jane Doe',
      'email': 'jane@example.com',
      'phone': '+15551234567',
    });
    expect(vcard, contains('BEGIN:VCARD'));
    expect(vcard, contains('FN:Jane Doe'));
    expect(vcard, contains('EMAIL:jane@example.com'));
    expect(vcard, contains('END:VCARD'));

    final vcal = buildQrOverlayPayload(kQrOverlayTemplateVcalendar, {
      'summary': 'Standup',
      'dtStart': '20260115T090000',
      'dtEnd': '20260115T093000',
      'location': 'Room A',
    });
    expect(vcal, contains('BEGIN:VCALENDAR'));
    expect(vcal, contains('SUMMARY:Standup'));
    expect(vcal, contains('END:VCALENDAR'));
  });

  test('custom reads payload field', () {
    expect(
      buildQrOverlayPayload(kQrOverlayTemplateCustom, {
        'payload': 'any raw data',
      }),
      'any raw data',
    );
  });

  test('empty when required fields missing', () {
    expect(buildQrOverlayPayload(kQrOverlayTemplateHttp, {}), '');
    expect(buildQrOverlayPayload(kQrOverlayTemplateWifi, {'ssid': ''}), '');
  });
}
