import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:waddle_shared/persistence/database.dart';

AppDatabase openMemoryDatabase() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

Future<void> warmDatabase(AppDatabase db) async {
  await db.customStatement('select 1');
}

/// Seed ad-hoc curator category rows (`curator_categories`) so tests can reference category ids
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
