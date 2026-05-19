import 'package:drift/drift.dart';
import 'package:waddle_shared/persistence/calendar_event_categories.dart';
import 'package:waddle_shared/persistence/database.dart';

/// Inserts or updates a calendar event row and replaces category assignments.
Future<void> upsertCalendarEventWithCategories(
  AppDatabase db, {
  required CalendarEventsCompanion companion,
  required List<String> categoryIds,
}) async {
  await db.into(db.calendarEvents).insertOnConflictUpdate(companion);
  final eventId = companion.id.value;
  await replaceCalendarEventCategoryAssignments(
    db,
    eventId: eventId,
    categoryIds: categoryIds,
  );
}
