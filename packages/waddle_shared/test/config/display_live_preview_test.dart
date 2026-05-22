import 'package:test/test.dart';
import 'package:waddle_shared/config/display_live_preview.dart';

void main() {
  test('defaults when KV empty', () {
    final c = displayLivePreviewConfigFromKv({});
    expect(c.enabled, isFalse);
    expect(c.configured, isFalse);
    expect(c.fps, kDefaultDisplayLivePreviewFps);
    expect(c.width, kDefaultDisplayLivePreviewWidth);
    expect(c.quality, kDefaultDisplayLivePreviewQuality);
  });

  test('configured when enabled', () {
    final c = displayLivePreviewConfigFromKv({
      kDisplayLivePreviewEnabledKvKey: 'true',
    });
    expect(c.configured, isTrue);
    expect(c.fps, 10);
  });

  test('normalizes fps width quality', () {
    final c = displayLivePreviewConfigFromKv({
      kDisplayLivePreviewEnabledKvKey: '1',
      kDisplayLivePreviewFpsKvKey: '99',
      kDisplayLivePreviewWidthKvKey: '50',
      kDisplayLivePreviewQualityKvKey: '10',
    });
    expect(c.fps, 30);
    expect(c.width, 320);
    expect(c.quality, 30);
  });
}
