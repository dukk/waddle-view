import 'package:waddle_shared/persistence/database.dart';
import 'dashboard_data_access.dart';

class DriftDashboardDataAccess implements DashboardDataAccess {
  DriftDashboardDataAccess(this._db);

  final AppDatabase _db;

  @override
  Stream<String?> watchHeaderTitle() {
    return (_db.select(_db.configKeyValues)
          ..where((t) => t.key.equals('header.title')))
        .watchSingleOrNull()
        .map((r) => r?.value);
  }

  @override
  Stream<String?> watchSlotSubtitle(String slotId) {
    final key = 'slot.$slotId.subtitle';
    return (_db.select(_db.configKeyValues)..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((r) => r?.value);
  }
}
