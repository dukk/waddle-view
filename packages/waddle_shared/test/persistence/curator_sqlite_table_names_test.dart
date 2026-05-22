import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test(
    'fresh database uses curator_categories and curator_rejected_terms',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name IN ('curator_categories','curator_rejected_terms',"
            "'content_categories','reject_terms')",
          )
          .get();
      final names = tables.map((r) => r.read<String>('name')).toSet();
      expect(names.contains('curator_categories'), isTrue);
      expect(names.contains('curator_rejected_terms'), isTrue);
      expect(names.contains('content_categories'), isFalse);
      expect(names.contains('reject_terms'), isFalse);
      await db.close();
    },
  );

  test(
    'beforeOpen creates curator_categories on legacy DB opened at v38',
    () async {
      final executor = NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE interests_locations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  include_weather INTEGER NOT NULL DEFAULT 0,
  include_weather_alerts INTEGER NOT NULL DEFAULT 0,
  include_local_news INTEGER NOT NULL DEFAULT 0
);
''');
          raw.execute('PRAGMA user_version = 38');
        },
      );
      final db = AppDatabase(
        DatabaseConnection(executor, closeStreamsSynchronously: true),
      );
      await warmDatabase(db);
      await seedContentCategoriesForTest(db, ['general']);
      final row = await (db.select(
        db.contentCategories,
      )..where((t) => t.id.equals('general'))).getSingleOrNull();
      expect(row, isNotNull);
      await db.close();
    },
  );
}
