import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../blob/blob_store.dart';
import 'database.dart';
import 'display_overlay_falling_images_settings.dart';

/// Maximum decoded bytes accepted for operator overlay image uploads.
const int kOverlayBlobUploadMaxBytes = 4 * 1024 * 1024;

const Set<String> kOverlayBlobUploadMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
};

/// Stores [bytes] in [blobs] and registers [blobMetadata] under [blobKey].
Future<void> registerOverlayBlob({
  required AppDatabase db,
  required BlobStore blobs,
  required String blobKey,
  required List<int> bytes,
  required String mimeType,
  DateTime? capturedAt,
}) async {
  if (!isValidOverlayBlobKey(blobKey)) {
    throw FormatException('invalid_overlay_blob_key');
  }
  final ref = await blobs.putBytes(bytes, logicalKey: blobKey.trim());
  final digest = sha256.convert(bytes).toString();
  await db.into(db.blobMetadata).insertOnConflictUpdate(
        BlobMetadataCompanion.insert(
          blobKey: blobKey.trim(),
          sha256: digest,
          relativePath: ref.storageKey,
          bytes: bytes.length,
          mimeType: Value(mimeType),
          capturedAt: capturedAt ?? DateTime.now().toUtc(),
        ),
      );
}

/// Allocates a unique blob key under `overlay/pool/`.
String allocateOverlayPoolBlobKey() {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final rand = (stamp % 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '${kOverlayBlobKeyPrefix}pool/$stamp-$rand';
}
