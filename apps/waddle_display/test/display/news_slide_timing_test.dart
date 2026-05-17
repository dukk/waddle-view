import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/news/news_slide_timing.dart';

void main() {
  group('scrollAnimationDurationMs', () {
    test('zero extent or speed yields zero', () {
      expect(
        scrollAnimationDurationMs(maxScrollExtent: 0, pixelsPerSecond: 50),
        0,
      );
      expect(
        scrollAnimationDurationMs(maxScrollExtent: 100, pixelsPerSecond: 0),
        0,
      );
    });

    test('duration scales with distance and speed', () {
      expect(
        scrollAnimationDurationMs(maxScrollExtent: 100, pixelsPerSecond: 50),
        2000,
      );
      expect(
        scrollAnimationDurationMs(maxScrollExtent: 50, pixelsPerSecond: 100),
        500,
      );
    });

    test('fractional seconds round up', () {
      expect(
        scrollAnimationDurationMs(maxScrollExtent: 1, pixelsPerSecond: 3),
        334,
      );
    });
  });

  group('desiredDwellMsForRssArticle', () {
    test('non-scrollable uses max of base and minRead', () {
      expect(
        desiredDwellMsForRssArticle(
          baseDwellMs: 12000,
          minReadMs: 8000,
          summaryScrollable: false,
          scrollDelayMs: 2500,
          trailingHoldMs: 2000,
          maxScrollExtent: 0,
          scrollPixelsPerSecond: 48,
        ),
        12000,
      );
      expect(
        desiredDwellMsForRssArticle(
          baseDwellMs: 5000,
          minReadMs: 8000,
          summaryScrollable: false,
          scrollDelayMs: 2500,
          trailingHoldMs: 2000,
          maxScrollExtent: 0,
          scrollPixelsPerSecond: 48,
        ),
        8000,
      );
    });

    test('scrollable uses delay + scroll + hold when larger than base', () {
      // 240px at 48 px/s => 5000ms scroll; content 9500 must exceed base floor
      expect(
        desiredDwellMsForRssArticle(
          baseDwellMs: 8000,
          minReadMs: 6000,
          summaryScrollable: true,
          scrollDelayMs: 2500,
          trailingHoldMs: 2000,
          maxScrollExtent: 240,
          scrollPixelsPerSecond: 48,
        ),
        2500 + 5000 + 2000,
      );
    });

    test('scrollable respects base floor when content is short', () {
      expect(
        desiredDwellMsForRssArticle(
          baseDwellMs: 12000,
          minReadMs: 8000,
          summaryScrollable: true,
          scrollDelayMs: 1000,
          trailingHoldMs: 500,
          maxScrollExtent: 10,
          scrollPixelsPerSecond: 100,
        ),
        12000,
      );
    });
  });
}
