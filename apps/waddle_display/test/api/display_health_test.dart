import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/api/display_health.dart';

void main() {
  test('buildDisplayHealthJson includes host and schema fields', () {
    final started = DateTime.utc(2026, 1, 1, 12, 0, 0);
    final now = started.add(const Duration(minutes: 5));
    final body = buildDisplayHealthJson(
      schemaVersion: 48,
      hostFacts: const DisplayHostFacts(
        operatingSystem: 'linux',
        operatingSystemVersion: 'Ubuntu 24.04',
        localHostname: 'pi-tv',
        numberOfProcessors: 4,
        dartVersion: 'Dart 3.11.5 (stable)',
      ),
      serverStartedAt: started,
      now: now,
    );

    expect(body['status'], 'ok');
    expect(body['app'], 'waddle_display');
    expect(body['version'], kWaddleDisplayAppVersion);
    expect(body['schema_version'], 48);
    expect(body['platform_os'], 'linux');
    expect(body['platform_os_version'], 'Ubuntu 24.04');
    expect(body['hostname'], 'pi-tv');
    expect(body['cpu_count'], 4);
    expect(body['dart_version'], startsWith('Dart'));
    expect(body['uptime_seconds'], 300);
  });
}
