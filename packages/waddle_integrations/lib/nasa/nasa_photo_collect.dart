import 'package:drift/drift.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/persistence/database.dart';

Future<void> pruneNasaPhotosByRetention(
  DataWriteContext ctx, {
  required String dataProvider,
  required int retentionDays,
  required int nowMs,
}) async {
  if (retentionDays <= 0) {
    return;
  }
  final cutoffMs = nowMs - Duration(days: retentionDays).inMilliseconds;
  final cutoff = DateTime.fromMillisecondsSinceEpoch(cutoffMs);
  final rows = await (ctx.db.select(ctx.db.photos)..where(
        (t) =>
            t.dataProvider.equals(dataProvider) &
            t.fetchedAtMs.isSmallerThanValue(cutoff),
      ))
      .get();
  for (final row in rows) {
    await deleteNasaPhoto(ctx, row);
  }
}

Future<void> pruneNasaPhotosByMaxCount(
  DataWriteContext ctx, {
  required String dataProvider,
  required int maxPhotos,
}) async {
  if (maxPhotos < 1) {
    return;
  }
  final rows = await (ctx.db.select(ctx.db.photos)
        ..where((t) => t.dataProvider.equals(dataProvider))
        ..orderBy([(t) => OrderingTerm.asc(t.fetchedAtMs)]))
      .get();
  if (rows.length <= maxPhotos) {
    return;
  }
  final removeCount = rows.length - maxPhotos;
  for (var i = 0; i < removeCount; i++) {
    await deleteNasaPhoto(ctx, rows[i]);
  }
}

Future<void> deleteNasaPhoto(DataWriteContext ctx, Photo row) async {
  final key = row.mediaBlobKey;
  final meta = await (ctx.db.select(ctx.db.blobMetadata)
        ..where((t) => t.blobKey.equals(key)))
      .getSingleOrNull();
  if (meta != null) {
    await ctx.blobs.delete(BlobRef(meta.relativePath));
    await (ctx.db.delete(ctx.db.blobMetadata)
          ..where((t) => t.blobKey.equals(key)))
        .go();
  }
  await (ctx.db.delete(ctx.db.photos)..where((t) => t.id.equals(row.id))).go();
}

Future<bool> storeNasaPhoto({
  required DataWriteContext ctx,
  required String photoId,
  required String dataProvider,
  required String category,
  required List<int> bytes,
  required String logicalKey,
  required String photographerName,
  required String pageUrl,
  required String altText,
  required int nowMs,
  String mimeType = 'image/jpeg',
}) async {
  final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);
  final blocked = rejectCtx.isMediaRejected(
    photographer: photographerName,
    altText: altText,
    urls: [pageUrl],
  );

  final ref = await ctx.blobs.putBytes(bytes, logicalKey: logicalKey);
  await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
        BlobMetadataCompanion.insert(
          blobKey: logicalKey,
          sha256: ref.storageKey.split('/').last,
          relativePath: ref.storageKey,
          bytes: bytes.length,
          mimeType: Value(mimeType),
          capturedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
        ),
      );

  await ctx.db.into(ctx.db.photos).insert(
        PhotosCompanion.insert(
          id: photoId,
          category: Value(category),
          dataProvider: Value(dataProvider),
          mediaBlobKey: logicalKey,
          photographerName: photographerName,
          photographerUrl: '',
          pageUrl: pageUrl,
          altText: Value(altText),
          fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
          suppressed: Value(blocked),
        ),
        mode: InsertMode.insertOrIgnore,
      );
  return !blocked;
}
