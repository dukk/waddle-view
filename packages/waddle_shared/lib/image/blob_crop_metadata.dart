import 'package:drift/drift.dart';

import '../blob/blob_store.dart';
import '../persistence/database.dart';
import 'smart_crop_focal.dart';

export 'smart_crop_focal.dart';

Uint8List _asUint8List(List<int> bytes) {
  if (bytes is Uint8List) {
    return bytes;
  }
  return Uint8List.fromList(bytes);
}

/// Upserts [blob_metadata] for an image blob, including crop analysis when possible.
Future<void> writeBlobMetadataWithCropAnalysis({
  required AppDatabase db,
  required String blobKey,
  required BlobRef ref,
  required List<int> bytes,
  String? mimeType,
  DateTime? capturedAt,
  BlobCropProviderHints hints = const BlobCropProviderHints(),
  bool analyze = true,
}) async {
  final data = _asUint8List(bytes);
  final analysis = analyze
      ? analyzeBlobCropMetadata(data, hints: hints)
      : analyzeBlobCropMetadata(
          data,
          hints: BlobCropProviderHints(
            altText: hints.altText,
            preferFace: hints.preferFace,
            skipAnalyze: true,
            pixelWidth: hints.pixelWidth,
            pixelHeight: hints.pixelHeight,
          ),
        );

  await db
      .into(db.blobMetadata)
      .insertOnConflictUpdate(
        BlobMetadataCompanion.insert(
          blobKey: blobKey,
          sha256: ref.storageKey.split('/').last,
          relativePath: ref.storageKey,
          bytes: data.length,
          mimeType: Value(mimeType),
          capturedAt: capturedAt ?? DateTime.now().toUtc(),
          pixelWidth: Value(analysis?.pixelWidth ?? hints.pixelWidth),
          pixelHeight: Value(analysis?.pixelHeight ?? hints.pixelHeight),
          focalX: Value(analysis?.focalX),
          focalY: Value(analysis?.focalY),
          hasFace: Value(analysis?.hasFace),
          hasText: Value(analysis?.hasText),
          cropHintsJson: Value(analysis?.cropHintsJson),
        ),
      );
}

/// Re-analyzes an existing blob and updates crop columns. Returns true on success.
Future<bool> backfillBlobCropMetadata({
  required AppDatabase db,
  required BlobStore blobs,
  required String blobKey,
  BlobCropProviderHints hints = const BlobCropProviderHints(),
}) async {
  final meta = await (db.select(
    db.blobMetadata,
  )..where((t) => t.blobKey.equals(blobKey))).getSingleOrNull();
  if (meta == null) {
    return false;
  }
  late final Uint8List bytes;
  try {
    bytes = _asUint8List(await blobs.readBytes(BlobRef(meta.relativePath)));
  } on Object {
    return false;
  }
  if (bytes.isEmpty) {
    return false;
  }
  final analysis = analyzeBlobCropMetadata(
    bytes,
    hints: BlobCropProviderHints(
      altText: hints.altText,
      preferFace: hints.preferFace,
      pixelWidth: hints.pixelWidth ?? meta.pixelWidth,
      pixelHeight: hints.pixelHeight ?? meta.pixelHeight,
    ),
  );
  if (analysis == null) {
    return false;
  }
  await (db.update(
    db.blobMetadata,
  )..where((t) => t.blobKey.equals(blobKey))).write(
    BlobMetadataCompanion(
      pixelWidth: Value(analysis.pixelWidth),
      pixelHeight: Value(analysis.pixelHeight),
      focalX: Value(analysis.focalX),
      focalY: Value(analysis.focalY),
      hasFace: Value(analysis.hasFace),
      hasText: Value(analysis.hasText),
      cropHintsJson: Value(analysis.cropHintsJson),
    ),
  );
  return true;
}

/// Backfills up to [limit] news-linked blobs missing [focalX].
Future<int> backfillMissingNewsImageCropMetadata({
  required AppDatabase db,
  required BlobStore blobs,
  int limit = 5,
}) async {
  if (limit < 1) {
    return 0;
  }
  final rows = await db
      .customSelect(
        '''
SELECT n.image_blob_key AS blob_key
FROM news n
INNER JOIN blob_metadata b ON b.blob_key = n.image_blob_key
WHERE n.image_blob_key IS NOT NULL
  AND trim(n.image_blob_key) != ''
  AND b.focal_x IS NULL
LIMIT ?
''',
        variables: [Variable<int>(limit)],
      )
      .get();

  var done = 0;
  for (final row in rows) {
    final key = row.read<String>('blob_key');
    if (await backfillBlobCropMetadata(db: db, blobs: blobs, blobKey: key)) {
      done++;
    }
  }
  return done;
}
