import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/api/network_addressing.dart';

void main() {
  test('parseCorsAllowedOrigins trims and splits', () {
    expect(parseCorsAllowedOrigins(null), isEmpty);
    expect(parseCorsAllowedOrigins(''), isEmpty);
    expect(
      parseCorsAllowedOrigins(' http://a.test ,http://b.test, '),
      ['http://a.test', 'http://b.test'],
    );
  });

  test('resolveHttpBindConfig defaults to loopback and port 8787', () async {
    final cfg = await resolveHttpBindConfig(
      environment: {'WADDLE_HTTP_TLS': '0'},
      tlsCertDir: '',
    );
    expect(cfg.port, 8787);
    expect(cfg.address, InternetAddress.loopbackIPv4);
    expect(cfg.displayHost, isNotEmpty);
    expect(cfg.tls.enabled, isFalse);
  });

  test('resolveHttpBindConfig defaults TLS on when tlsCertDir set', () async {
    final cfg = await resolveHttpBindConfig(
      environment: {},
      tlsCertDir: Directory.systemTemp.path,
    );
    expect(cfg.tls.enabled, isTrue);
    expect(cfg.tls.certPath, isNotNull);
    expect(cfg.tls.keyPath, isNotNull);
  });

  test('resolveHttpBindConfig honors WADDLE_HTTP_BIND and port', () async {
    final cfg = await resolveHttpBindConfig(
      environment: {
        'WADDLE_HTTP_BIND': '0.0.0.0',
        'WADDLE_HTTP_PORT': '9999',
        'WADDLE_HTTP_TLS': '0',
      },
      tlsCertDir: '',
    );
    expect(cfg.port, 9999);
    expect(cfg.address, InternetAddress.anyIPv4);
    expect(cfg.displayHost, isNot(equals('0.0.0.0')));
  });

  test('resolveHttpBindConfig falls back on invalid host', () async {
    final cfg = await resolveHttpBindConfig(
      environment: {'WADDLE_HTTP_BIND': 'not-an-ip', 'WADDLE_HTTP_TLS': '0'},
      tlsCertDir: '',
    );
    expect(cfg.address, InternetAddress.loopbackIPv4);
  });

  test('resolveHttpBindConfig supports IPv6 any bind', () async {
    final cfg = await resolveHttpBindConfig(
      environment: {'WADDLE_HTTP_BIND': '::', 'WADDLE_HTTP_TLS': '0'},
      tlsCertDir: '',
    );
    expect(cfg.address, InternetAddress.anyIPv6);
  });
}
