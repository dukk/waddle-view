import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/display/display_viewport_reserve.dart';

void main() {
  test('normalizeViewportReservePct clamps to 0–50', () {
    expect(normalizeViewportReservePct(null), 0);
    expect(normalizeViewportReservePct(''), 0);
    expect(normalizeViewportReservePct('abc'), 0);
    expect(normalizeViewportReservePct('10'), 10);
    expect(normalizeViewportReservePct('99'), 50);
    expect(normalizeViewportReservePct('-5'), 0);
  });

  test('parseDisplayViewportReservePctFromKv reads four keys', () {
    final reserve = parseDisplayViewportReservePctFromKv({
      kDisplayViewportReserveTopPctKvKey: '12',
      kDisplayViewportReserveRightPctKvKey: '5',
      kDisplayViewportReserveBottomPctKvKey: '3',
      kDisplayViewportReserveLeftPctKvKey: '8',
    });
    expect(reserve.top, 12);
    expect(reserve.right, 5);
    expect(reserve.bottom, 3);
    expect(reserve.left, 8);
  });

  test('mergeDisplayViewportReservePct applies per-side overrides', () {
    const global = DisplayViewportReservePct(
      top: 5,
      right: 10,
      bottom: 15,
      left: 20,
    );
    final merged = mergeDisplayViewportReservePct(
      global,
      topOverride: 25,
      leftOverride: null,
    );
    expect(merged.top, 25);
    expect(merged.right, 10);
    expect(merged.bottom, 15);
    expect(merged.left, 20);
  });

  test('normalizeViewportReservePctOverride returns null for empty', () {
    expect(normalizeViewportReservePctOverride(null), isNull);
    expect(normalizeViewportReservePctOverride(''), isNull);
    expect(normalizeViewportReservePctOverride('  '), isNull);
    expect(normalizeViewportReservePctOverride(12), 12);
  });
}
