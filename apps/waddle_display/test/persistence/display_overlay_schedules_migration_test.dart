import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test(
    'fresh AppDatabase exposes display_overlay_schedules at schema v28',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);

    final ver = await db.customSelect('PRAGMA user_version').getSingle();
    expect(ver.data.values.single, 28);

      final check = await db.customSelect(
        "SELECT COUNT(*) AS c FROM sqlite_master WHERE "
        "type='table' AND name='display_overlay_schedules'",
      ).getSingle();
      expect(check.read<int>('c'), 1);

      await db.close();
    },
  );
}
