import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/content_category_defaults.dart';
import 'package:waddle_shared/persistence/database.dart';

/// Idempotent inserts for [ContentCategories] (icons: material name and/or blob key).
Future<void> ensureDefaultContentCategories(AppDatabase db) async {
  for (final d in kContentCategoryDefaults) {
    final existing =
        await (db.select(db.contentCategories)..where((t) => t.id.equals(d.id)))
            .getSingleOrNull();
    if (existing != null) {
      continue;
    }
    await db.into(db.contentCategories).insert(
          ContentCategoriesCompanion.insert(
            id: d.id,
            label: d.label,
            iconBlobKey: d.iconBlobKey == null
                ? const Value.absent()
                : Value(d.iconBlobKey),
            materialIconName: d.materialIconName == null
                ? const Value.absent()
                : Value(d.materialIconName),
          ),
        );
  }
}
