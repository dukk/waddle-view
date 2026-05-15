import 'dart:typed_data';

import 'blob_store.dart';

/// Result of a kiosk-safe display-time [BlobStore.readBytes] (never throws).
final class DisplayBlobBytes {
  const DisplayBlobBytes._({this.bytes, required this.readFailed});

  const DisplayBlobBytes.absent()
    : bytes = null,
      readFailed = false;

  const DisplayBlobBytes.ok(Uint8List data)
    : bytes = data,
      readFailed = false;

  const DisplayBlobBytes.readFailed()
    : bytes = null,
      readFailed = true;

  final Uint8List? bytes;
  final bool readFailed;

  bool get isOk => bytes != null;
}

/// Reads [ref] for on-screen display. Missing files and I/O errors return
/// [DisplayBlobBytes.absent] or [DisplayBlobBytes.readFailed] instead of throwing.
Future<DisplayBlobBytes> readDisplayBlobBytes(
  BlobStore store,
  BlobRef ref,
) async {
  try {
    final raw = await store.readBytes(ref);
    if (raw.isEmpty) {
      return const DisplayBlobBytes.absent();
    }
    return DisplayBlobBytes.ok(Uint8List.fromList(raw));
  } catch (_) {
    return const DisplayBlobBytes.readFailed();
  }
}
