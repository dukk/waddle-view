import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/tables/overlay_blobs_seed.dart';

import '../helpers/memory_database.dart';

class _MemBlobStore implements BlobStore {
  final Map<String, List<int>> _data = {};

  @override
  Future<void> delete(BlobRef ref) async => _data.remove(ref.storageKey);

  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async {
    final key = 'stored/$logicalKey';
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
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  test('ensureOverlayBlobSeed registers duck SVG blobs idempotently', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = _MemBlobStore();

    await ensureOverlayBlobSeed(db: db, blobs: blobs);
    await ensureOverlayBlobSeed(db: db, blobs: blobs);

    final rows = await db.select(db.blobMetadata).get();
    expect(rows.map((r) => r.blobKey).toSet(), kSeededDuckOverlayBlobKeys.toSet());
    for (final row in rows) {
      expect(row.mimeType, 'image/svg+xml');
      expect(row.bytes, greaterThan(100));
    }

    final mascotRow = rows.singleWhere((r) => r.blobKey == kOverlayBlobKeyDuckMascot);
    final mascotBytes = await blobs.readBytes(BlobRef(mascotRow.relativePath));
    expect(String.fromCharCodes(mascotBytes.take(20)), startsWith('<?xml'));

    await db.close();
  });
}
