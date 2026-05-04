import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/blob/filesystem_blob_store.dart';

void main() {
  test('put read delete roundtrip', () async {
    final dir = await Directory.systemTemp.createTemp('waddle_blob_');
    try {
      final store = FileSystemBlobStore(dir);
      final ref = await store.putBytes([1, 2, 3], logicalKey: 'k');
      final bytes = await store.readBytes(ref);
      expect(bytes, [1, 2, 3]);
      await store.delete(ref);
      await expectLater(store.readBytes(ref), throwsException);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
