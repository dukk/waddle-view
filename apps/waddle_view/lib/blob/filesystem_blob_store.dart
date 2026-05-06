import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'blob_store.dart';

/// Content-addressed-ish paths under [rootDirectory] with temp+rename writes.
class FileSystemBlobStore implements BlobStore {
  FileSystemBlobStore(this.rootDirectory);

  final Directory rootDirectory;

  String _shardPath(String hexDigest) {
    final a = hexDigest.substring(0, 2);
    final b = hexDigest.substring(2, 4);
    return p.join(a, b, hexDigest);
  }

  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async {
    final digest = sha256.convert(bytes).toString();
    final rel = _shardPath(digest);
    final dir = Directory(p.join(rootDirectory.path, p.dirname(rel)));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final target = File(p.join(rootDirectory.path, rel));
    final tmp = File('${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(target.path);
    return BlobRef(rel);
  }

  @override
  Future<List<int>> readBytes(BlobRef ref) async {
    final f = File(p.join(rootDirectory.path, ref.storageKey));
    return f.readAsBytes();
  }

  @override
  Future<void> delete(BlobRef ref) async {
    final f = File(p.join(rootDirectory.path, ref.storageKey));
    if (await f.exists()) {
      await f.delete();
    }
  }

  @override
  File? tryLocalFile(BlobRef ref) {
    final f = File(p.join(rootDirectory.path, ref.storageKey));
    return f.existsSync() ? f : null;
  }
}
