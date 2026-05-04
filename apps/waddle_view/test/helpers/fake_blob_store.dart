import 'package:waddle_view/blob/blob_store.dart';

class FakeBlobStore implements BlobStore {
  final Map<String, List<int>> _bytes = {};

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
}
