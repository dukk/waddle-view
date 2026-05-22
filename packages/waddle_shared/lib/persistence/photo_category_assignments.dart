import 'package:drift/drift.dart';

import 'database.dart';
import 'media_category_ids.dart';

export 'media_category_ids.dart'
    show
        normalizeMediaCategoryIds,
        parseMediaConfigCategoryIds,
        resolveMediaCategoryIds;

/// Replaces junction rows; sets [Photos.category] to the primary (first) id.
Future<void> replacePhotoCategoryAssignments(
  AppDatabase db, {
  required String photoId,
  required List<String> categoryIds,
}) async {
  final normalized = await resolveMediaCategoryIds(db, categoryIds);
  await (db.delete(
    db.photoCategories,
  )..where((t) => t.photoId.equals(photoId))).go();
  for (final cat in normalized) {
    await db
        .into(db.photoCategories)
        .insert(
          PhotoCategoriesCompanion.insert(photoId: photoId, categoryId: cat),
          mode: InsertMode.insertOrIgnore,
        );
  }
  if (normalized.isEmpty) {
    return;
  }
  await (db.update(db.photos)..where((t) => t.id.equals(photoId))).write(
    PhotosCompanion(category: Value(normalized.first)),
  );
}

/// Returns true when [categoryId] is linked to any photo (junction or legacy).
Future<bool> photoCategoryIdInUse(AppDatabase db, String categoryId) async {
  final junction =
      await (db.select(db.photoCategories)
            ..where((t) => t.categoryId.equals(categoryId))
            ..limit(1))
          .getSingleOrNull();
  if (junction != null) {
    return true;
  }
  final legacy =
      await (db.select(db.photos)
            ..where((t) => t.category.equals(categoryId))
            ..limit(1))
          .getSingleOrNull();
  return legacy != null;
}
