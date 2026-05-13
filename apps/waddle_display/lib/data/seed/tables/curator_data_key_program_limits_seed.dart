import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/database.dart';

Future<void> ensureCuratorDataKeyProgramLimitsSeed(AppDatabase db) async {
  await db.into(db.curatorDataKeyProgramLimits).insertOnConflictUpdate(
        CuratorDataKeyProgramLimitsCompanion.insert(
          dataKey: 'clock',
          minPlacementsPerProgram: const Value(1),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}
