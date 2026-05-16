import 'package:drift/drift.dart';

import '../clock.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'active_alert_selector.dart';
import 'alert_repository.dart';

class DriftAlertRepository implements AlertRepository {
  DriftAlertRepository(this._db, {ActiveAlertSelector? selector})
    : _selector = selector ?? const ActiveAlertSelector();

  final AppDatabase _db;
  final ActiveAlertSelector _selector;

  @override
  Future<int> insertAlert({
    required String title,
    required String body,
    String? qrPayload,
    String severity = 'info',
    int priority = 0,
    int? expiresAtMs,
  }) async {
    final id = await _db
        .into(_db.alerts)
        .insert(
          AlertsCompanion.insert(
            title: title,
            body: body,
            qrPayload: Value(qrPayload),
            severity: Value(severity),
            priority: Value(priority),
            createdAt: DateTime.now(),
            expiresAt: Value(
              expiresAtMs == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
            ),
          ),
        );
    return id;
  }

  @override
  Future<void> dismiss(int id) async {
    await (_db.update(_db.alerts)..where((t) => t.id.equals(id)))
        .write(
          AlertsCompanion(
            dismissedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Stream<DashboardAlert?> watchActive(Clock clock) {
    return (_db.select(_db.alerts)
          ..where((t) => t.dismissedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch()
        .map((rows) => _selector.pick(rows, clock.now()));
  }
}
