import 'package:flutter/services.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/overlay_blob_storage.dart';
import 'package:waddle_shared/persistence/tables.dart';

const _kOverlayDuckSeedAssetPrefix =
    'packages/waddle_shared/seed/assets/overlay_ducks/';

const _kDuckSeedAssetFiles = <String, String>{
  kOverlayBlobKeyDuckMascot: 'duck_mascot.svg',
  kOverlayBlobKeyDuckHeadshot1: 'duck_headshot_1.svg',
  kOverlayBlobKeyDuckHeadshot2: 'duck_headshot_2.svg',
};

Future<List<int>> readOverlayDuckSeedAssetBytes(String fileName) async {
  final data = await rootBundle.load('$_kOverlayDuckSeedAssetPrefix$fileName');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// Idempotently registers duck mascot SVG blobs for `falling_images` overlays.
Future<void> ensureOverlayBlobSeed({
  required AppDatabase db,
  required BlobStore blobs,
}) async {
  for (final entry in _kDuckSeedAssetFiles.entries) {
    final existing = await (db.select(db.blobMetadata)
          ..where((t) => t.blobKey.equals(entry.key)))
        .getSingleOrNull();
    if (existing != null) {
      continue;
    }
    final bytes = await readOverlayDuckSeedAssetBytes(entry.value);
    await registerOverlayBlob(
      db: db,
      blobs: blobs,
      blobKey: entry.key,
      bytes: bytes,
      mimeType: 'image/svg+xml',
    );
  }
}
