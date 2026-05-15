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
}
