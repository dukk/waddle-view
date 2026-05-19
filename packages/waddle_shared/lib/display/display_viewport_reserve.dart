/// Viewport edge reserve (percent of letterboxed viewport) for screen + ticker.
library;

const String kDisplayViewportReserveTopPctKvKey =
    'display.viewport.reserve_top_pct';
const String kDisplayViewportReserveRightPctKvKey =
    'display.viewport.reserve_right_pct';
const String kDisplayViewportReserveBottomPctKvKey =
    'display.viewport.reserve_bottom_pct';
const String kDisplayViewportReserveLeftPctKvKey =
    'display.viewport.reserve_left_pct';

const int kViewportReservePctMin = 0;
const int kViewportReservePctMax = 50;

/// Percent reserves on each edge of the letterboxed viewport (0–50).
class DisplayViewportReservePct {
  const DisplayViewportReservePct({
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.left = 0,
  });

  final int top;
  final int right;
  final int bottom;
  final int left;

  static const zero = DisplayViewportReservePct();

  @override
  bool operator ==(Object other) {
    return other is DisplayViewportReservePct &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom &&
        other.left == left;
  }

  @override
  int get hashCode => Object.hash(top, right, bottom, left);
}

int normalizeViewportReservePct(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return 0;
  }
  final parsed = int.tryParse(raw.trim());
  if (parsed == null) {
    return 0;
  }
  return parsed.clamp(kViewportReservePctMin, kViewportReservePctMax);
}

DisplayViewportReservePct parseDisplayViewportReservePctFromKv(
  Map<String, String> kv,
) {
  return DisplayViewportReservePct(
    top: normalizeViewportReservePct(kv[kDisplayViewportReserveTopPctKvKey]),
    right: normalizeViewportReservePct(kv[kDisplayViewportReserveRightPctKvKey]),
    bottom:
        normalizeViewportReservePct(kv[kDisplayViewportReserveBottomPctKvKey]),
    left: normalizeViewportReservePct(kv[kDisplayViewportReserveLeftPctKvKey]),
  );
}

/// Per-side merge: [topOverride] etc. when non-null replace [global] for that side.
DisplayViewportReservePct mergeDisplayViewportReservePct(
  DisplayViewportReservePct global, {
  int? topOverride,
  int? rightOverride,
  int? bottomOverride,
  int? leftOverride,
}) {
  return DisplayViewportReservePct(
    top: topOverride ?? global.top,
    right: rightOverride ?? global.right,
    bottom: bottomOverride ?? global.bottom,
    left: leftOverride ?? global.left,
  );
}

int? normalizeViewportReservePctOverride(dynamic raw) {
  if (raw == null) {
    return null;
  }
  if (raw is String && raw.trim().isEmpty) {
    return null;
  }
  return normalizeViewportReservePct('$raw');
}
