import 'package:test/test.dart';

import '../helpers/memory_database.dart';

void main() {
  test(
    'fresh AppDatabase exposes overlays at current schema',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);

      final ver = await db.customSelect('PRAGMA user_version').getSingle();
      expect(ver.read<int>('user_version'), 46);

      final check = await db.customSelect(
        "SELECT COUNT(*) AS c FROM sqlite_master WHERE "
        "type='table' AND name='overlays'",
      ).getSingle();
      expect(check.read<int>('c'), 1);

      final legacy = await db.customSelect(
        "SELECT COUNT(*) AS c FROM sqlite_master WHERE "
        "type='table' AND name='display_overlay_schedules'",
      ).getSingle();
      expect(legacy.read<int>('c'), 0);

      final overlayCols = await db.customSelect(
        'PRAGMA table_info(overlays);',
      ).get();
      final overlayNames = overlayCols.map((r) => r.read<String>('name')).toSet();
      expect(overlayNames.contains('overlay_type'), isTrue);
      expect(overlayNames.contains('config_json'), isTrue);
      expect(overlayNames.contains('config_json_schema'), isTrue);
      expect(overlayNames.contains('example_config_json'), isTrue);
      expect(overlayNames.contains('messages_json'), isFalse);

      final wlCols =
          await db.customSelect('PRAGMA table_info(weather_locations);').get();
      final wlNames = wlCols.map((r) => r.read<String>('name')).toSet();
      expect(wlNames.contains('include_active_weather_alerts'), isTrue);

      await db.close();
    },
  );
}
