import 'dart:typed_data';

/// WebSocket frame: 4-byte big-endian payload length + 1-byte format + payload.
const int kLivePreviewFrameHeaderBytes = 5;

const int kLivePreviewFrameFormatJpeg = 0;
const int kLivePreviewFrameFormatPng = 1;

/// Legacy header size (length + raw JPEG with no format byte).
const int kLivePreviewLegacyFrameHeaderBytes = 4;

Uint8List encodeLivePreviewFrame(
  Uint8List payload, {
  int format = kLivePreviewFrameFormatJpeg,
}) {
  final out = Uint8List(kLivePreviewFrameHeaderBytes + payload.length);
  final view = ByteData.sublistView(out);
  view.setUint32(0, payload.length, Endian.big);
  view.setUint8(4, format);
  out.setRange(kLivePreviewFrameHeaderBytes, out.length, payload);
  return out;
}

/// True when [buf] uses the pre-format-byte wire layout.
bool isLegacyLivePreviewFrame(Uint8List buf, int payloadLen) {
  if (buf.length < kLivePreviewLegacyFrameHeaderBytes + payloadLen) {
    return false;
  }
  if (payloadLen < 2) return false;
  return buf[kLivePreviewLegacyFrameHeaderBytes] == 0xFF &&
      buf[kLivePreviewLegacyFrameHeaderBytes + 1] == 0xD8;
}

/// Splits a byte buffer into complete JPEG images (SOI … EOI).
List<Uint8List> extractJpegFramesFromBuffer(List<int> buffer) {
  final frames = <Uint8List>[];
  var i = 0;
  while (i < buffer.length - 1) {
    if (buffer[i] != 0xFF || buffer[i + 1] != 0xD8) {
      i++;
      continue;
    }
    final start = i;
    i += 2;
    while (i < buffer.length - 1) {
      if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
        i += 2;
        frames.add(Uint8List.fromList(buffer.sublist(start, i)));
        break;
      }
      i++;
    }
    if (i >= buffer.length - 1 && frames.isEmpty) break;
  }
  return frames;
}

/// Remaining bytes after the last complete JPEG (if any).
List<int> jpegBufferRemainder(List<int> buffer) {
  var lastStart = -1;
  for (var i = 0; i < buffer.length - 1; i++) {
    if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
      lastStart = i;
    }
  }
  if (lastStart < 0) return [];
  var end = lastStart + 2;
  while (end < buffer.length - 1) {
    if (buffer[end] == 0xFF && buffer[end + 1] == 0xD9) {
      return buffer.sublist(end + 2);
    }
    end++;
  }
  return buffer.sublist(lastStart);
}
