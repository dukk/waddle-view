import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/api/network_addressing.dart';

void main() {
  test('defaults to loopback and port 8787', () async {
    final cfg = await resolveHttpBindConfig(environment: const {});
    expect(cfg.port, 8787);
    expect(cfg.address.address, '127.0.0.1');
  });

  test('accepts explicit bind and port', () async {
    final cfg = await resolveHttpBindConfig(
      environment: const {
        'WADDLE_HTTP_BIND': '0.0.0.0',
        'WADDLE_HTTP_PORT': '9999',
      },
    );
    expect(cfg.port, 9999);
    expect(cfg.address.address, '0.0.0.0');
  });

  test('binds all IPv6 and falls back port when invalid', () async {
    final v6 = await resolveHttpBindConfig(
      environment: const {'WADDLE_HTTP_BIND': '::'},
    );
    expect(v6.address, InternetAddress.anyIPv6);

    final badPort = await resolveHttpBindConfig(
      environment: const {'WADDLE_HTTP_PORT': '0'},
    );
    expect(badPort.port, 8787);

    final badHost = await resolveHttpBindConfig(
      environment: const {'WADDLE_HTTP_BIND': 'not-a-host-name!!!'},
    );
    expect(badHost.address, InternetAddress.loopbackIPv4);
  });
}
