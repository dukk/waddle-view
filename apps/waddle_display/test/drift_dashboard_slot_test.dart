import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/display/drift_dashboard_data_access.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'helpers/memory_database.dart';

void main() {
  test('watchSlotSubtitle', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final access = DriftDashboardDataAccess(db);
    expect(await access.watchSlotSubtitle('x').first, equals(null));
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(key: 'slot.x.subtitle', value: 'S'),
        );
    expect(await access.watchSlotSubtitle('x').first, 'S');
    await db.close();
  });
}
