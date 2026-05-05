/// Milliseconds to scroll from offset 0 to [maxScrollExtent] at [pixelsPerSecond].
int scrollAnimationDurationMs({
  required double maxScrollExtent,
  required double pixelsPerSecond,
}) {
  if (maxScrollExtent <= 0 || pixelsPerSecond <= 0) {
    return 0;
  }
  return (maxScrollExtent / pixelsPerSecond * 1000).ceil();
}

/// Total slide dwell so the article can be read (and scrolled when needed).
///
/// [baseDwellMs] is the screen definition floor. [minReadMs] applies when the
/// summary fits without scrolling.
int desiredDwellMsForRssArticle({
  required int baseDwellMs,
  required int minReadMs,
  required bool summaryScrollable,
  required int scrollDelayMs,
  required int trailingHoldMs,
  required double maxScrollExtent,
  required double scrollPixelsPerSecond,
}) {
  if (!summaryScrollable) {
    return baseDwellMs > minReadMs ? baseDwellMs : minReadMs;
  }
  final scrollMs = scrollAnimationDurationMs(
    maxScrollExtent: maxScrollExtent,
    pixelsPerSecond: scrollPixelsPerSecond,
  );
  final contentMs = scrollDelayMs + scrollMs + trailingHoldMs;
  return contentMs > baseDwellMs ? contentMs : baseDwellMs;
}
