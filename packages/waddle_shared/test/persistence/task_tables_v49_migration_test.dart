import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('fresh database has task_lists and tasks at schema 49', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 49);
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('task_lists', 'tasks') ORDER BY name",
    ).get();
    expect(tables.map((r) => r.read<String>('name')).toList(), ['task_lists', 'tasks']);
  });
}
