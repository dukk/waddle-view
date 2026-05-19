import 'dart:async';

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
    String source = 'api',
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
            source: Value(source),
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
    final driftStream = (_db.select(_db.alerts)
          ..where((t) => t.dismissedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();

    final controller = StreamController<DashboardAlert?>();
    StreamSubscription<List<DashboardAlert>>? driftSub;
    Timer? expiryTimer;

    void emitPick(List<DashboardAlert> rows) {
      if (controller.isClosed) {
        return;
      }
      controller.add(_selector.pick(rows, clock.now()));
      _scheduleExpiryTick(rows, clock, (next) {
        expiryTimer?.cancel();
        expiryTimer = next;
      }, () {
        if (controller.isClosed) {
          return;
        }
        controller.add(_selector.pick(rows, clock.now()));
      });
    }

    driftSub = driftStream.listen(
      emitPick,
      onError: controller.addError,
      onDone: () async {
        expiryTimer?.cancel();
        await controller.close();
      },
    );

    controller.onCancel = () async {
      expiryTimer?.cancel();
      await driftSub?.cancel();
    };

    return controller.stream;
  }
}

/// Schedules a one-shot timer for the nearest future [expiresAt] among [rows].
void _scheduleExpiryTick(
  List<DashboardAlert> rows,
  Clock clock,
  void Function(Timer? timer) setTimer,
  void Function() onTick,
) {
  final now = clock.now();
  DateTime? nextExpiry;
  for (final row in rows) {
    final exp = row.expiresAt;
    if (exp == null || !exp.isAfter(now)) {
      continue;
    }
    if (nextExpiry == null || exp.isBefore(nextExpiry)) {
      nextExpiry = exp;
    }
  }
  setTimer(null);
  if (nextExpiry == null) {
    return;
  }
  final delay = nextExpiry.difference(now);
  setTimer(
    Timer(delay.isNegative ? Duration.zero : delay, onTick),
  );
}
