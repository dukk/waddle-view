import 'dart:typed_data';

import 'package:drift/drift.dart'
    show CustomExpression, Expression, OrderingTerm;
import 'package:waddle_display/blob/blob_store.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';

/// Loads a [Photo] row chosen for this slide ([spec.choiceKey] in [slide.randomChoices]).
Future<Photo?> loadPexelsPhotoForSlide(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide,
) async {
  final curatedId = slide.randomChoices[spec.choiceKey];
  if (curatedId != null && curatedId.isNotEmpty) {
    return (db.select(db.photos)
          ..where(
            (t) => Expression.and([
              t.id.equals(curatedId),
              t.suppressed.equals(false),
            ]),
          ))
        .getSingleOrNull();
  }
  final categoryId = spec.config['categoryId'] as String?;
  final q = db.select(db.photos);
  if (categoryId != null && categoryId.isNotEmpty) {
    q.where(
      (t) => Expression.and([
        t.category.equals(categoryId),
        t.suppressed.equals(false),
      ]),
    );
  } else {
    q.where((t) => t.suppressed.equals(false));
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
  return (db.select(db.photos)
        ..where(
          (t) => Expression.and([
            t.id.equals(curatedId),
            t.suppressed.equals(false),
          ]),
        ))
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
