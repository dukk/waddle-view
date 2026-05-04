/// Opaque handle to stored blob bytes.
class BlobRef {
  const BlobRef(this.storageKey);

  final String storageKey;

  @override
  bool operator ==(Object other) =>
      other is BlobRef && other.storageKey == storageKey;

  @override
  int get hashCode => storageKey.hashCode;
}

/// Large binaries live outside SQLite; metadata is tracked separately.
abstract class BlobStore {
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey});

  Future<List<int>> readBytes(BlobRef ref);

  Future<void> delete(BlobRef ref);
}
