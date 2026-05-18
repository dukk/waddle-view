import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/display_overlay_falling_images_settings.dart';
import 'package:waddle_shared/persistence/overlay_blob_storage.dart';

import '../helpers/memory_database.dart';

class _MemBlobStore implements BlobStore {
  final Map<String, List<int>> _data = {};

  @override
  Future<void> delete(BlobRef ref) async => _data.remove(ref.storageKey);

  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async {
    final key = 'stored/${bytes.length}';
    _data[key] = List<int>.from(bytes);
    return BlobRef(key);
  }

  @override
  Future<List<int>> readBytes(BlobRef ref) async =>
      List<int>.from(_data[ref.storageKey] ?? const []);

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

void main() {
  test('registerOverlayBlob stores metadata', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = _MemBlobStore();
    const key = 'overlay/pool/test';
    final bytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ),
    );
    await registerOverlayBlob(
      db: db,
      blobs: blobs,
      blobKey: key,
      bytes: bytes,
      mimeType: 'image/png',
    );
    final row = await (db.select(db.blobMetadata)
          ..where((t) => t.blobKey.equals(key)))
        .getSingleOrNull();
    expect(row, isNotNull);
    await db.close();
  });

  test('allocateOverlayPoolBlobKey is valid', () {
    final key = allocateOverlayPoolBlobKey();
    expect(isValidOverlayBlobKey(key), isTrue);
  });
}
