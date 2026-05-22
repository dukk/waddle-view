/// Shared vertical scroll dwell timing for slides with scrollable content.
int scrollAnimationDurationMs({
  required double maxScrollExtent,
  required double pixelsPerSecond,
}) {
  if (maxScrollExtent <= 0 || pixelsPerSecond <= 0) {
    return 0;
  }
  return (maxScrollExtent / pixelsPerSecond * 1000).ceil();
}

int desiredDwellMsForVerticalScroll({
  required int baseDwellMs,
  required int minReadMs,
  required bool scrollable,
  required int scrollDelayMs,
  required int trailingHoldMs,
  required double maxScrollExtent,
  required double scrollPixelsPerSecond,
}) {
  if (!scrollable) {
    return baseDwellMs > minReadMs ? baseDwellMs : minReadMs;
  }
  final scrollMs = scrollAnimationDurationMs(
    maxScrollExtent: maxScrollExtent,
    pixelsPerSecond: scrollPixelsPerSecond,
  );
  final contentMs = scrollDelayMs + scrollMs + trailingHoldMs;
  return contentMs > baseDwellMs ? contentMs : baseDwellMs;
}
