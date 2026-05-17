import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/pexels/pexels_video_playback.dart';

void main() {
  test('pexelsVideoLayoutSizeReady rejects zero and tiny sizes', () {
    expect(pexelsVideoLayoutSizeReady(0, 1080), isFalse);
    expect(pexelsVideoLayoutSizeReady(3840, 0), isFalse);
    expect(pexelsVideoLayoutSizeReady(1, 1), isFalse);
    expect(
      pexelsVideoLayoutSizeReady(
        kPexelsVideoMinLayoutExtent - 1,
        kPexelsVideoMinLayoutExtent,
      ),
      isFalse,
    );
  });

  test('pexelsVideoLayoutSizeReady accepts signage viewport sizes', () {
    expect(pexelsVideoLayoutSizeReady(3840, 2160), isTrue);
    expect(
      pexelsVideoLayoutSizeReady(
        kPexelsVideoMinLayoutExtent,
        kPexelsVideoMinLayoutExtent,
      ),
      isTrue,
    );
  });

  test('pexelsVideoLayoutSizeReady rejects non-finite extents', () {
    expect(pexelsVideoLayoutSizeReady(double.infinity, 100), isFalse);
    expect(pexelsVideoLayoutSizeReady(100, double.nan), isFalse);
  });

  test('pexelsVideoRetryDelay grows with attempt', () {
    expect(pexelsVideoRetryDelay(1), const Duration(milliseconds: 400));
    expect(pexelsVideoRetryDelay(2), const Duration(milliseconds: 800));
    expect(pexelsVideoRetryDelay(99), const Duration(milliseconds: 1200));
  });

  test('pexelsVideoTextureDimensions caps embedded budget', () {
    embeddedSignageLinuxHostOverride = true;
    maxTexturePixelCountOverride = 1920 * 1080;
    addTearDown(() {
      embeddedSignageLinuxHostOverride = null;
      maxTexturePixelCountOverride = null;
    });

    final dims = pexelsVideoTextureDimensions(
      layoutWidth: 3840,
      layoutHeight: 2160,
    );
    expect(dims.width * dims.height, lessThanOrEqualTo(1920 * 1080));
    expect(dims.width, greaterThanOrEqualTo(kPexelsVideoMinLayoutExtent.round()));
    expect(dims.height, greaterThanOrEqualTo(kPexelsVideoMinLayoutExtent.round()));
  });

  test('pexelsVideoTextureDimensions unchanged when under cap', () {
    maxTexturePixelCountOverride = 1920 * 1080;
    addTearDown(() => maxTexturePixelCountOverride = null);

    final dims = pexelsVideoTextureDimensions(
      layoutWidth: 1280,
      layoutHeight: 720,
    );
    expect(dims.width, 1280);
    expect(dims.height, 720);
  });

  test('pexelsVideoMaxTexturePixelCount reads env override', () {
    maxTexturePixelCountOverride = 640 * 480;
    addTearDown(() => maxTexturePixelCountOverride = null);
    expect(pexelsVideoMaxTexturePixelCount(), 640 * 480);
  });

  test('embedded default texture cap is 720p', () {
    embeddedSignageLinuxHostOverride = true;
    maxTexturePixelCountOverride = null;
    addTearDown(() {
      embeddedSignageLinuxHostOverride = null;
    });
    expect(
      pexelsVideoMaxTexturePixelCount(),
      kPexelsVideoDefaultEmbeddedMaxTexturePixels,
    );
    expect(kPexelsVideoDefaultEmbeddedMaxTexturePixels, 1280 * 720);
  });

  test('pexelsVideoHwdecForPlayback uses embedded drm default', () {
    embeddedSignageLinuxHostOverride = true;
    pexelsVideoHwdecOverride = null;
    addTearDown(() {
      embeddedSignageLinuxHostOverride = null;
      pexelsVideoHwdecOverride = null;
    });
    expect(pexelsVideoHwdecForPlayback(), kPexelsVideoDefaultEmbeddedHwdec);
  });

  test('pexelsVideoHwdecForPlayback honors test override', () {
    pexelsVideoHwdecOverride = 'no';
    addTearDown(() => pexelsVideoHwdecOverride = null);
    expect(pexelsVideoHwdecForPlayback(), 'no');
  });

  test('pexelsVideoControllerConfiguration passes hwdec on embedded', () {
    embeddedSignageLinuxHostOverride = true;
    pexelsVideoHwdecOverride = 'drm';
    addTearDown(() {
      embeddedSignageLinuxHostOverride = null;
      pexelsVideoHwdecOverride = null;
    });
    final cfg = pexelsVideoControllerConfiguration(
      layoutWidth: 1920,
      layoutHeight: 1080,
    );
    expect(cfg.hwdec, 'drm');
    expect(cfg.width, lessThanOrEqualTo(1920));
    expect(cfg.height, lessThanOrEqualTo(1080));
  });
}
