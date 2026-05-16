import 'package:test/test.dart';

import '../helpers/memory_database.dart';

void main() {
  test('fresh database creates weather_alerts table', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='weather_alerts'",
    ).get();
    expect(rows.length, 1);
    await db.close();
  });

  test('fresh database creates weather_current table', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='weather_current'",
    ).get();
    expect(rows.length, 1);
    await db.close();
  });

  test('fresh database creates alerts table', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='alerts'",
    ).get();
    expect(rows.length, 1);
    await db.close();
  });

  test('fresh database creates screens table', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='screens'",
    ).get();
    expect(rows.length, 1);
    await db.close();
  });
}
