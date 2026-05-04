import 'package:drift/drift.dart';

import '../persistence/database.dart';
import 'ticker_models.dart';
import 'ticker_schedule_repository.dart';

class DriftTickerScheduleRepository implements TickerScheduleRepository {
  DriftTickerScheduleRepository(this._db);

  final AppDatabase _db;

  String _dayKey(DateTime local) =>
      '${local.year}-${local.month}-${local.day}';

  @override
  Future<List<TickerScreenBundle>> loadBundles() async {
    final screens = await (_db.select(
      _db.tickerScreens,
    )..where((s) => s.enabled.equals(true))).get();
    final out = <TickerScreenBundle>[];
    for (final s in screens) {
      final groups = await (_db.select(
        _db.tickerConditionGroups,
      )..where((g) => g.screenId.equals(s.id))).get();
      final bundles = <TickerConditionGroupBundle>[];
      for (final g in groups) {
        final conds = await (_db.select(
          _db.tickerConditions,
        )..where((c) => c.groupId.equals(g.id))).get();
        bundles.add(TickerConditionGroupBundle(group: g, conditions: conds));
      }
      final runtime =
          await (_db.select(
            _db.tickerScreenRuntimes,
          )..where((r) => r.screenId.equals(s.id))).getSingleOrNull();
      out.add(TickerScreenBundle(screen: s, groups: bundles, runtime: runtime));
    }
    out.sort((a, b) => a.screen.sortKey.compareTo(b.screen.sortKey));
    return out;
  }

  @override
  Future<void> onShowStart(String screenId, DateTime nowLocal) async {
    final existing =
        await (_db.select(
          _db.tickerScreenRuntimes,
        )..where((r) => r.screenId.equals(screenId))).getSingleOrNull();
    await _db.into(_db.tickerScreenRuntimes).insertOnConflictUpdate(
      TickerScreenRuntimesCompanion(
        screenId: Value(screenId),
        lastStartedAt: Value(nowLocal.millisecondsSinceEpoch),
        lastEndedAt: Value(existing?.lastEndedAt),
        showsOnLocalDay: Value(existing?.showsOnLocalDay ?? 0),
        localDayKey: Value(existing?.localDayKey),
      ),
    );
  }

  @override
  Future<void> onShowEnd(String screenId, DateTime nowLocal) async {
    final existing =
        await (_db.select(
          _db.tickerScreenRuntimes,
        )..where((r) => r.screenId.equals(screenId))).getSingleOrNull();
    final dayKey = _dayKey(nowLocal);
    var shows = 0;
    if (existing?.localDayKey == dayKey) {
      shows = (existing?.showsOnLocalDay ?? 0) + 1;
    } else {
      shows = 1;
    }
    await _db.into(_db.tickerScreenRuntimes).insertOnConflictUpdate(
      TickerScreenRuntimesCompanion(
        screenId: Value(screenId),
        lastEndedAt: Value(nowLocal.millisecondsSinceEpoch),
        showsOnLocalDay: Value(shows),
        localDayKey: Value(dayKey),
        lastStartedAt: Value(existing?.lastStartedAt),
      ),
    );
  }
}
