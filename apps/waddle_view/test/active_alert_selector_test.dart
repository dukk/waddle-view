import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/alerts/active_alert_selector.dart';
import 'package:waddle_view/clock.dart';
import 'package:waddle_view/persistence/database.dart';

void main() {
  test('picks highest priority non-expired non-dismissed', () {
    const sel = ActiveAlertSelector();
    final now = DateTime.utc(2026, 5, 3, 12);
    final rows = [
      DashboardAlert(
        id: 1,
        title: 'a',
        body: '',
        qrPayload: null,
        severity: 'info',
        priority: 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        expiresAt: null,
        dismissedAt: null,
        source: 'api',
      ),
      DashboardAlert(
        id: 2,
        title: 'b',
        body: '',
        qrPayload: null,
        severity: 'info',
        priority: 5,
        createdAt: DateTime.fromMillisecondsSinceEpoch(2),
        expiresAt: null,
        dismissedAt: null,
        source: 'api',
      ),
    ];
    final picked = sel.pick(rows, now);
    expect(picked?.id, 2);
  });

  test('respects expires_at', () {
    const sel = ActiveAlertSelector();
    final now = DateTime.utc(2026, 5, 3, 12);
    final rows = [
      DashboardAlert(
        id: 1,
        title: 'a',
        body: '',
        qrPayload: null,
        severity: 'info',
        priority: 9,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          now.millisecondsSinceEpoch - 1,
        ),
        dismissedAt: null,
        source: 'api',
      ),
    ];
    expect(sel.pick(rows, now), isNull);
  });

  test('pickWithClock', () {
    const sel = ActiveAlertSelector();
    final clock = FakeClock(DateTime.utc(2026, 1, 1));
    final rows = <DashboardAlert>[];
    expect(sel.pickWithClock(rows, clock), isNull);
  });
}
