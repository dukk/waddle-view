import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/api/network_addressing.dart';
import 'package:waddle_display/config/display_env.dart';

void main() {
  test('parseCorsAllowedOrigins trims and splits', () {
    expect(parseCorsAllowedOrigins(null), isEmpty);
    expect(parseCorsAllowedOrigins(''), isEmpty);
    expect(
      parseCorsAllowedOrigins(' http://a.test ,http://b.test, '),
      ['http://a.test', 'http://b.test'],
    );
  });

  test('resolveHttpBindConfig defaults to all interfaces and port 8787', () async {
    final cfg = await resolveHttpBindConfig(
      environment: {kDisplayHttpTlsEnv: '0'},
      tlsCertDir: '',
    );
    expect(cfg.port, 8787);
    expect(cfg.address, InternetAddress.anyIPv4);
    expect(cfg.displayHost, isNotEmpty);
    expect(cfg.displayHost, isNot(equals('0.0.0.0')));
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

  test('resolveHttpBindConfig honors WADDLE_DISPLAY_HTTP_BIND_IP and port', () async {
    final cfg = await resolveHttpBindConfig(
      environment: {
        kDisplayHttpBindIpEnv: '127.0.0.1',
        kDisplayHttpPortEnv: '9999',
        kDisplayHttpTlsEnv: '0',
      },
      tlsCertDir: '',
    );
    expect(cfg.port, 9999);
    expect(cfg.address, InternetAddress.loopbackIPv4);
    expect(cfg.displayHost, isNotEmpty);
  });

  test('resolveHttpBindConfig falls back on invalid host', () async {
    final cfg = await resolveHttpBindConfig(
      environment: {
        kDisplayHttpBindIpEnv: 'not-an-ip',
        kDisplayHttpTlsEnv: '0',
      },
      tlsCertDir: '',
    );
    expect(cfg.address, InternetAddress.anyIPv4);
  });

  test('resolveHttpBindConfig supports IPv6 any bind', () async {
    final cfg = await resolveHttpBindConfig(
      environment: {
        kDisplayHttpBindIpEnv: '::',
        kDisplayHttpTlsEnv: '0',
      },
      tlsCertDir: '',
    );
    expect(cfg.address, InternetAddress.anyIPv6);
  });
}
