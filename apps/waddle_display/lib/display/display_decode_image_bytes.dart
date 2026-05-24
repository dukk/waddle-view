import 'dart:typed_data';
import 'dart:ui' as ui;

/// Returns whether [bytes] can be decoded as a raster image on this host.
///
/// [readDisplayBlobBytes] only validates I/O; corrupt, truncated, or
/// unsupported formats (for example HEIC on some Linux builds) can still fail
/// later in [MemoryImage] / [Image.memory] unless probed first.
Future<bool> canDecodeDisplayImageBytes(Uint8List bytes) async {
  if (bytes.isEmpty) {
    return false;
  }
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    codec.dispose();
    return true;
  } catch (_) {
    return false;
  }
}
