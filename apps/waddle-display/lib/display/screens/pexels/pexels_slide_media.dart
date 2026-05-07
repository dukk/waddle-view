import 'dart:typed_data';

import 'package:drift/drift.dart' show CustomExpression, OrderingTerm;
import 'package:waddle_view/blob/blob_store.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/curator/screen_program_curator.dart';
import 'package:waddle_view/persistence/database.dart';

/// Loads a [Photo] row chosen for this slide ([spec.choiceKey] in [slide.randomChoices]).
Future<Photo?> loadPexelsPhotoForSlide(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide,
) async {
  final curatedId = slide.randomChoices[spec.choiceKey];
  if (curatedId != null && curatedId.isNotEmpty) {
    return (db.select(db.photos)..where((t) => t.id.equals(curatedId)))
        .getSingleOrNull();
  }
  final categoryId = spec.config['categoryId'] as String?;
  final q = db.select(db.photos);
  if (categoryId != null && categoryId.isNotEmpty) {
    q.where((t) => t.category.equals(categoryId));
  }
  return (q
        ..orderBy([
          (t) => OrderingTerm(expression: const CustomExpression('random()')),
        ])
        ..limit(1))
      .getSingleOrNull();
}

Future<Photo?> loadPhotoByCuratedId(AppDatabase db, String? curatedId) async {
  if (curatedId == null || curatedId.isEmpty) {
    return null;
  }
  return (db.select(db.photos)..where((t) => t.id.equals(curatedId)))
      .getSingleOrNull();
}

Future<Uint8List?> loadPhotoBlobBytes(
  AppDatabase db,
  BlobStore blobs,
  Photo row,
) async {
  final meta =
      await (db.select(db.blobMetadata)
            ..where((t) => t.blobKey.equals(row.mediaBlobKey)))
          .getSingleOrNull();
  if (meta == null) {
    return null;
  }
  final bytes = await blobs.readBytes(BlobRef(meta.relativePath));
  return bytes.isEmpty ? null : Uint8List.fromList(bytes);
}
