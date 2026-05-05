import 'dart:math' as math;

/// Linear duration for scrolling [contentWidthPx] at [pixelsPerSecond].
Duration marqueeScrollDuration({
  required double contentWidthPx,
  required double pixelsPerSecond,
}) {
  if (contentWidthPx <= 0 || pixelsPerSecond <= 0) {
    return const Duration(milliseconds: 1);
  }
  final ms = (contentWidthPx / pixelsPerSecond * 1000).round();
  return Duration(milliseconds: math.max(1, ms));
}
