import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/api/network_addressing.dart';

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
}
