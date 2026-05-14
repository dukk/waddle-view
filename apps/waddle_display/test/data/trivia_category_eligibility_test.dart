import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_data_providers/trivia_openai/trivia_category_eligibility.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('non-seasonal category is always eligible', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.triviaCategories).insert(
          TriviaCategoriesCompanion.insert(id: 'a', label: 'A'),
        );
    final row =
        await (db.select(db.triviaCategories)..where((t) => t.id.equals('a')))
            .getSingle();
    expect(isTriviaCategoryEligibleOn(row, DateTime(2026, 7, 4)), isTrue);
    await db.close();
  });

  test('seasonal category with incomplete window is never eligible', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.triviaCategories).insert(
          TriviaCategoriesCompanion.insert(
            id: 's',
            label: 'S',
            isSeasonal: const Value(true),
            startMonth: const Value(12),
            startDay: const Value(1),
            endMonth: const Value(1),
          ),
        );
    final row =
        await (db.select(db.triviaCategories)..where((t) => t.id.equals('s')))
            .getSingle();
    expect(isTriviaCategoryEligibleOn(row, DateTime(2026, 12, 15)), isFalse);
    await db.close();
  });
}
