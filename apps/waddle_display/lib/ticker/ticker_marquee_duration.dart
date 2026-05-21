import 'dart:math' as math;

/// Linear duration for scrolling [scrollDistancePx] at [pixelsPerSecond].
///
/// For the ticker marquee, [scrollDistancePx] is typically
/// `segmentWidth + viewportWidth` so content enters from the right edge.
Duration marqueeScrollDuration({
  required double scrollDistancePx,
  required double pixelsPerSecond,
}) {
  if (scrollDistancePx <= 0 || pixelsPerSecond <= 0) {
    return const Duration(milliseconds: 1);
  }
  final ms = (scrollDistancePx / pixelsPerSecond * 1000).round();
  return Duration(milliseconds: math.max(1, ms));
}
