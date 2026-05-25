import 'package:test/test.dart';
import 'package:waddle_shared/config/display_collect_settings.dart';

void main() {
  tearDown(() {
    DisplayCollectEnvDefaults.collectIdleSeconds = null;
    DisplayCollectEnvDefaults.lowPowerEnabled = null;
  });

  test('normalizeDisplayCollectIdleSeconds clamps range', () {
    expect(normalizeDisplayCollectIdleSeconds(10), 15);
    expect(normalizeDisplayCollectIdleSeconds(45), 45);
    expect(normalizeDisplayCollectIdleSeconds(900), 600);
  });

  test('resolveDisplayCollectIdleSeconds uses KV then env', () {
    DisplayCollectEnvDefaults.collectIdleSeconds = 90;
    expect(
      resolveDisplayCollectIdleSeconds({
        kDisplayCollectIdleSecondsKvKey: '120',
      }),
      120,
    );
    expect(resolveDisplayCollectIdleSeconds({}), 90);
  });

  test('low power raises idle floor to 60s', () {
    expect(
      resolveDisplayCollectIdleSeconds({
        kDisplayLowPowerEnabledKvKey: 'true',
        kDisplayCollectIdleSecondsKvKey: '30',
      }),
      60,
    );
    expect(
      resolveDisplayCollectIdleSeconds({
        kDisplayLowPowerEnabledKvKey: 'true',
        kDisplayCollectIdleSecondsKvKey: '120',
      }),
      120,
    );
  });

  test('effectiveDisplayTickerPixelsPerSecond caps in low power', () {
    expect(
      effectiveDisplayTickerPixelsPerSecond(
        configuredPixelsPerSecond: 80,
        kv: {kDisplayLowPowerEnabledKvKey: 'true'},
      ),
      kDisplayLowPowerMaxTickerPixelsPerSecond,
    );
    expect(
      effectiveDisplayTickerPixelsPerSecond(
        configuredPixelsPerSecond: 30,
        kv: {kDisplayLowPowerEnabledKvKey: 'true'},
      ),
      30,
    );
  });

  test('debug mode forces 5s idle', () {
    expect(
      resolveDisplayCollectIdleSeconds({
        kDisplayCollectIdleSecondsKvKey: '120',
      }, debugMode: true),
      5,
    );
  });
}
