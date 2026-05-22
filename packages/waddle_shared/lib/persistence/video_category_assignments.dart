import 'package:drift/drift.dart';

import 'database.dart';
import 'media_category_ids.dart';

export 'media_category_ids.dart'
    show
        normalizeMediaCategoryIds,
        parseMediaConfigCategoryIds,
        resolveMediaCategoryIds;

/// Replaces junction rows; sets [Videos.category] to the primary (first) id.
Future<void> replaceVideoCategoryAssignments(
  AppDatabase db, {
  required String videoId,
  required List<String> categoryIds,
}) async {
  final normalized = await resolveMediaCategoryIds(db, categoryIds);
  await (db.delete(
    db.videoCategories,
  )..where((t) => t.videoId.equals(videoId))).go();
  for (final cat in normalized) {
    await db
        .into(db.videoCategories)
        .insert(
          VideoCategoriesCompanion.insert(videoId: videoId, categoryId: cat),
          mode: InsertMode.insertOrIgnore,
        );
  }
  if (normalized.isEmpty) {
    return;
  }
  await (db.update(db.videos)..where((t) => t.id.equals(videoId))).write(
    VideosCompanion(category: Value(normalized.first)),
  );
}

/// Returns true when [categoryId] is linked to any video (junction or legacy).
Future<bool> videoCategoryIdInUse(AppDatabase db, String categoryId) async {
  final junction =
      await (db.select(db.videoCategories)
            ..where((t) => t.categoryId.equals(categoryId))
            ..limit(1))
          .getSingleOrNull();
  if (junction != null) {
    return true;
  }
  final legacy =
      await (db.select(db.videos)
            ..where((t) => t.category.equals(categoryId))
            ..limit(1))
          .getSingleOrNull();
  return legacy != null;
}
