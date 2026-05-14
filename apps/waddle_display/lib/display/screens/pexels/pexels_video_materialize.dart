import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';

/// Resolves a local [File] for [row] media: direct blob path or temp copy.
Future<File> materializePexelsVideoFile(
  AppDatabase db,
  BlobStore blobs,
  Video row,
) async {
  final meta =
      await (db.select(db.blobMetadata)
            ..where((t) => t.blobKey.equals(row.mediaBlobKey)))
          .getSingleOrNull();
  if (meta == null) {
    throw StateError('missing blob metadata');
  }
  final ref = BlobRef(meta.relativePath);
  final direct = blobs.tryLocalFile(ref);
  if (direct != null) {
    return direct;
  }
  final bytes = await blobs.readBytes(ref);
  if (bytes.isEmpty) {
    throw StateError('empty video bytes');
  }
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/pexels_vid_${row.id}.mp4');
  await f.writeAsBytes(bytes, flush: true);
  return f;
}
