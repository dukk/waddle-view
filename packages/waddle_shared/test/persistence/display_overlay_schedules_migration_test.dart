import 'package:test/test.dart';

import '../helpers/memory_database.dart';

void main() {
  test(
    'fresh AppDatabase exposes display_overlay_schedules at schema v30',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);

      final ver = await db.customSelect('PRAGMA user_version').getSingle();
      expect(ver.data.values.single, 30);

      final check = await db.customSelect(
        "SELECT COUNT(*) AS c FROM sqlite_master WHERE "
        "type='table' AND name='display_overlay_schedules'",
      ).getSingle();
      expect(check.read<int>('c'), 1);

      final wlCols =
          await db.customSelect('PRAGMA table_info(weather_locations);').get();
      final wlNames = wlCols.map((r) => r.read<String>('name')).toSet();
      expect(wlNames.contains('include_active_weather_alerts'), isTrue);

      await db.close();
    },
  );
}
