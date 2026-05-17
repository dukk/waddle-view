import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 4 to 5 adds home assistant entity tables', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('PRAGMA user_version = 4');
    });
    final connection = DatabaseConnection(
      executor,
      closeStreamsSynchronously: true,
    );

    final db = AppDatabase(connection);
    await db.customStatement('SELECT 1');

    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('interests_home_assistant_entities', "
      "'home_assistant_entity_states')",
    ).get();
    expect(tables.length, 2);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 5);

    await db.close();
  });

  test('home_assistant_entity_states requires matching interest entity_id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.interestsHomeAssistantEntities).insert(
          InterestsHomeAssistantEntitiesCompanion.insert(
            id: 'ha1',
            entityId: 'sensor.temp',
          ),
        );
    await db.into(db.homeAssistantEntityStates).insert(
          HomeAssistantEntityStatesCompanion.insert(
            entityId: 'sensor.temp',
            state: '21.5',
            attributesJson: '{}',
            observedAtMs: 1,
          ),
        );
    expect(
      () => db.into(db.homeAssistantEntityStates).insert(
            HomeAssistantEntityStatesCompanion.insert(
              entityId: 'sensor.missing',
              state: 'off',
              attributesJson: '{}',
              observedAtMs: 2,
            ),
          ),
      throwsA(isA<Exception>()),
    );
    await db.close();
  });
}
