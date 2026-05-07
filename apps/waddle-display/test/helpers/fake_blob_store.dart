import 'dart:io';

import 'package:waddle_display/blob/blob_store.dart';

class FakeBlobStore implements BlobStore {
  final Map<String, List<int>> _bytes = {};

  void seed(String key, List<int> bytes) {
    _bytes[key] = List<int>.from(bytes);
  }

  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async {
    final key = '${logicalKey}_${bytes.length}';
    _bytes[key] = List<int>.from(bytes);
    return BlobRef(key);
  }

  @override
  Future<List<int>> readBytes(BlobRef ref) async =>
      List<int>.from(_bytes[ref.storageKey] ?? const []);

  @override
  Future<void> delete(BlobRef ref) async {
    _bytes.remove(ref.storageKey);
  }

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

/// [readBytes] always throws — for exercising blob read error UI.
class FailingReadBlobStore implements BlobStore {
  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> readBytes(BlobRef ref) async {
    throw StateError('simulated blob read failure');
  }

  @override
  Future<void> delete(BlobRef ref) async {}

  @override
  File? tryLocalFile(BlobRef ref) => null;
}
