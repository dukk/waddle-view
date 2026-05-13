import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/display/drift_dashboard_data_access.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'helpers/memory_database.dart';

void main() {
  test('watchHeaderTitle reflects inserts', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final access = DriftDashboardDataAccess(db);
    expect(await access.watchHeaderTitle().first, equals(null));
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(key: 'header.title', value: 'X'),
        );
    expect(await access.watchHeaderTitle().first, 'X');
    await db.close();
  });
}
