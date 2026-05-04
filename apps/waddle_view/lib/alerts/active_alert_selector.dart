import '../clock.dart';
import '../persistence/database.dart';

/// Picks the top active alert using [Clock] for expiry.
class ActiveAlertSelector {
  const ActiveAlertSelector();

  DashboardAlert? pick(List<DashboardAlert> rows, DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    DashboardAlert? best;
    for (final r in rows) {
      if (r.dismissedAt != null) {
        continue;
      }
      final exp = r.expiresAt;
      if (exp != null && exp <= nowMs) {
        continue;
      }
      if (best == null) {
        best = r;
        continue;
      }
      if (r.priority > best.priority) {
        best = r;
      } else if (r.priority == best.priority &&
          r.createdAt > best.createdAt) {
        best = r;
      }
    }
    return best;
  }

  DashboardAlert? pickWithClock(List<DashboardAlert> rows, Clock clock) =>
      pick(rows, clock.now());
}
