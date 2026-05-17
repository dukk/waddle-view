import 'package:test/test.dart';

import '../helpers/memory_database.dart';

void main() {
  test(
    'fresh in-memory AppDatabase has curator tables and screens.min_dwell_seconds',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);

      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name IN ('curator_configurations','curator_schedule_rules',"
        "'curator_configuration_members')",
      ).get();
      final names = tables.map((r) => r.read<String>('name')).toSet();
      expect(names.contains('curator_configurations'), isTrue);
      expect(names.contains('curator_schedule_rules'), isTrue);
      expect(names.contains('curator_configuration_members'), isTrue);

      final screenCols =
          await db.customSelect('PRAGMA table_info(screens);').get();
      final screenNames =
          screenCols.map((r) => r.read<String>('name')).toSet();
      expect(screenNames.contains('min_dwell_seconds'), isTrue);
      expect(screenNames.contains('dwell_seconds'), isFalse);

      await db.close();
    },
  );
}
