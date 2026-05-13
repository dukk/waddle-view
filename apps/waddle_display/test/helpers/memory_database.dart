import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

AppDatabase openMemoryDatabase() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

Future<void> warmDatabase(AppDatabase db, {String? displayTimeZoneIana}) async {
  await db.customStatement('select 1');
  if (displayTimeZoneIana != null) {
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTimezoneKvKey,
            value: displayTimeZoneIana,
          ),
        );
  }
}

/// Seed ad-hoc `content_categories` rows so tests can reference category ids
/// (FK target of e.g. `calendar_events.category_id`) without depending on
/// `ensureInitialSeed`. Pass each id you intend to use; label defaults to id.
Future<void> seedContentCategoriesForTest(
  AppDatabase db,
  Iterable<String> ids, {
  String? label,
}) async {
  for (final id in ids) {
    await db.into(db.contentCategories).insertOnConflictUpdate(
          ContentCategoriesCompanion.insert(
            id: id,
            label: label ?? id,
          ),
        );
  }
}
