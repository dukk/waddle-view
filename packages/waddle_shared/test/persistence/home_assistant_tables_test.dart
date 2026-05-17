import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test(
    'opened database includes home assistant entity and state tables',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name IN ('interests_home_assistant_entities', "
        "'home_assistant_entity_states')",
      ).get();
      final names = tables.map((r) => r.read<String>('name')).toSet();
      expect(names, {
        'interests_home_assistant_entities',
        'home_assistant_entity_states',
      });
      await db.close();
    },
  );
}
