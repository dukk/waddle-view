import 'package:drift/drift.dart';

import 'database.dart';

/// Normalizes category ids: trim, drop empties, preserve first-seen order.
List<String> normalizeCalendarEventCategoryIds(Iterable<String?> raw) {
  final out = <String>[];
  final seen = <String>{};
  for (final id in raw) {
    final t = id?.trim() ?? '';
    if (t.isEmpty || seen.contains(t)) {
      continue;
    }
    seen.add(t);
    out.add(t);
  }
  return out;
}

/// Parses `categoryId` / `category` / `categoryIds` from integration config JSON.
List<String> parseCalendarConfigCategoryIds(Object? raw) {
  if (raw == null) {
    return const [];
  }
  if (raw is String) {
    return normalizeCalendarEventCategoryIds([raw]);
  }
  if (raw is List<dynamic>) {
    return normalizeCalendarEventCategoryIds(
      raw.map((e) => e is String ? e : null),
    );
  }
  return const [];
}

/// Replaces junction rows and sets [CalendarEvents.categoryId] to the primary
/// (first) category, or null when [categoryIds] is empty.
Future<void> replaceCalendarEventCategoryAssignments(
  AppDatabase db, {
  required String eventId,
  required List<String> categoryIds,
}) async {
  final normalized = normalizeCalendarEventCategoryIds(categoryIds);
  await (db.delete(db.calendarEventCategories)
        ..where((t) => t.eventId.equals(eventId)))
      .go();
  for (final cat in normalized) {
    await db.into(db.calendarEventCategories).insert(
          CalendarEventCategoriesCompanion.insert(
            eventId: eventId,
            categoryId: cat,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
  await (db.update(db.calendarEvents)..where((t) => t.id.equals(eventId))).write(
    CalendarEventsCompanion(
      categoryId: Value(normalized.isEmpty ? null : normalized.first),
    ),
  );
}

/// Returns true when any calendar event is linked to [categoryId] (junction or legacy column).
Future<bool> calendarCategoryIdInUse(AppDatabase db, String categoryId) async {
  final junction = await (db.select(db.calendarEventCategories)
        ..where((t) => t.categoryId.equals(categoryId))
        ..limit(1))
      .getSingleOrNull();
  if (junction != null) {
    return true;
  }
  final legacy = await (db.select(db.calendarEvents)
        ..where((t) => t.categoryId.equals(categoryId))
        ..limit(1))
      .getSingleOrNull();
  return legacy != null;
}
