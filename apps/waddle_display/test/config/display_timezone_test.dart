import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:waddle_display/config/display_timezone.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('empty value uses default Eastern IANA id', () {
    final loc = resolveDisplayTimeZoneLocation('');
    expect(loc.name, kDefaultDisplayTimezoneIana);
  });

  test('invalid IANA falls back to default', () {
    final loc = resolveDisplayTimeZoneLocation('Not/A_Real_Zone_999');
    expect(loc.name, kDefaultDisplayTimezoneIana);
  });

  test('Europe/London resolves', () {
    final loc = resolveDisplayTimeZoneLocation('Europe/London');
    expect(loc.name, 'Europe/London');
  });

  test('watchDisplayTimezoneKv first yield when row present', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTimezoneKvKey,
            value: 'Europe/Paris',
          ),
        );
    final first = await watchDisplayTimezoneKv(db).first;
    expect(first, 'Europe/Paris');
    await db.close();
  });

  test('watchDisplayTimezoneKv emits after key upsert', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final seen = <String?>[];
    final sub = watchDisplayTimezoneKv(db).listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTimezoneKvKey,
            value: 'Pacific/Honolulu',
          ),
        );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(seen, contains('Pacific/Honolulu'));
    await db.close();
  });
}
