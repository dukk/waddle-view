import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/alerts/active_alert_selector.dart';
import 'package:waddle_display/persistence/database.dart';

void main() {
  test('same priority picks newer createdAt', () {
    const sel = ActiveAlertSelector();
    final now = DateTime.utc(2026, 5, 3);
    final rows = [
      DashboardAlert(
        id: 1,
        title: 'old',
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
        title: 'new',
        body: '',
        qrPayload: null,
        severity: 'info',
        priority: 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(5),
        expiresAt: null,
        dismissedAt: null,
        source: 'api',
      ),
    ];
    expect(sel.pick(rows, now)?.id, 2);
  });
}
