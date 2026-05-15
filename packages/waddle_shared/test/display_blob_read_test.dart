import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/blob/display_blob_read.dart';

class _BytesBlobStore implements BlobStore {
  _BytesBlobStore(this._map);

  final Map<String, List<int>> _map;

  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> readBytes(BlobRef ref) async =>
      List<int>.from(_map[ref.storageKey] ?? const []);

  @override
  Future<void> delete(BlobRef ref) async {}

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

class _ThrowingBlobStore implements BlobStore {
  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> readBytes(BlobRef ref) async {
    throw StateError('simulated read failure');
  }

  @override
  Future<void> delete(BlobRef ref) async {}

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

void main() {
  test('readDisplayBlobBytes returns ok for non-empty bytes', () async {
    final store = _BytesBlobStore({'k': [1, 2]});
    final result = await readDisplayBlobBytes(store, const BlobRef('k'));
    expect(result.isOk, isTrue);
    expect(result.readFailed, isFalse);
    expect(result.bytes, Uint8List.fromList([1, 2]));
  });

  test('readDisplayBlobBytes returns absent for empty bytes', () async {
    final store = _BytesBlobStore({'k': []});
    final result = await readDisplayBlobBytes(store, const BlobRef('k'));
    expect(result.bytes, isNull);
    expect(result.readFailed, isFalse);
  });

  test('readDisplayBlobBytes returns readFailed when readBytes throws', () async {
    final result = await readDisplayBlobBytes(
      _ThrowingBlobStore(),
      const BlobRef('k'),
    );
    expect(result.bytes, isNull);
    expect(result.readFailed, isTrue);
  });
}
