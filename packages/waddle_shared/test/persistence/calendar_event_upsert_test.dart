import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/calendar_event_upsert.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('upsertCalendarEventWithCategories inserts event and junction rows', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['work', 'family']);

    final start = DateTime.utc(2026, 5, 20, 10);
    final end = DateTime.utc(2026, 5, 20, 11);
    await upsertCalendarEventWithCategories(
      db,
      companion: CalendarEventsCompanion.insert(
        id: 'evt1',
        title: 'Standup',
        startMs: start,
        endMs: end,
        updatedAtMs: start,
      ),
      categoryIds: ['work', 'family'],
    );

    final row = await (db.select(db.calendarEvents)
          ..where((t) => t.id.equals('evt1')))
        .getSingle();
    expect(row.title, 'Standup');
    expect(row.categoryId, 'work');

    final junction = await (db.select(db.calendarEventCategories)
          ..where((t) => t.eventId.equals('evt1')))
        .get();
    expect(
      junction.map((r) => r.categoryId).toList()..sort(),
      ['family', 'work'],
    );
  });

  test('upsert replaces category assignments on conflict', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['work', 'family']);

    final start = DateTime.utc(2026, 5, 21);
    final companion = CalendarEventsCompanion.insert(
      id: 'evt2',
      title: 'Review',
      startMs: start,
      endMs: start.add(const Duration(hours: 1)),
      updatedAtMs: start,
    );
    await upsertCalendarEventWithCategories(
      db,
      companion: companion,
      categoryIds: ['work'],
    );
    await upsertCalendarEventWithCategories(
      db,
      companion: companion.copyWith(title: const Value('Review (moved)')),
      categoryIds: ['family'],
    );

    final row = await (db.select(db.calendarEvents)
          ..where((t) => t.id.equals('evt2')))
        .getSingle();
    expect(row.title, 'Review (moved)');
    expect(row.categoryId, 'family');

    final junction = await (db.select(db.calendarEventCategories)
          ..where((t) => t.eventId.equals('evt2')))
        .get();
    expect(junction, hasLength(1));
    expect(junction.single.categoryId, 'family');
  });
}
