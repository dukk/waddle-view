const LIVE_PREVIEW_FRAME_HEADER_BYTES = 5;
const LIVE_PREVIEW_LEGACY_HEADER_BYTES = 4;

export type LivePreviewFrame = {
  mime: string;
  payload: ArrayBuffer;
};

export function parseLivePreviewFrame(buf: ArrayBuffer): LivePreviewFrame | null {
  if (buf.byteLength < LIVE_PREVIEW_LEGACY_HEADER_BYTES) return null;
  const view = new DataView(buf);
  const len = view.getUint32(0, false);
  if (len <= 0) return null;

  const bytes = new Uint8Array(buf);
  const legacy =
    bytes.length >= LIVE_PREVIEW_LEGACY_HEADER_BYTES + len &&
    bytes[LIVE_PREVIEW_LEGACY_HEADER_BYTES] === 0xff &&
    bytes[LIVE_PREVIEW_LEGACY_HEADER_BYTES + 1] === 0xd8;

  if (legacy) {
    return {
      mime: 'image/jpeg',
      payload: buf.slice(
        LIVE_PREVIEW_LEGACY_HEADER_BYTES,
        LIVE_PREVIEW_LEGACY_HEADER_BYTES + len,
      ),
    };
  }

  if (buf.byteLength < LIVE_PREVIEW_FRAME_HEADER_BYTES + len) return null;
  const format = view.getUint8(4);
  const mime = format === 1 ? 'image/png' : 'image/jpeg';
  return {
    mime,
    payload: buf.slice(
      LIVE_PREVIEW_FRAME_HEADER_BYTES,
      LIVE_PREVIEW_FRAME_HEADER_BYTES + len,
    ),
  };
}

export function livePreviewFrameExtension(mime: string): 'jpg' | 'png' {
  return mime === 'image/png' ? 'png' : 'jpg';
}

export function buildLivePreviewFrameFilename(
  displayId: string,
  mime: string,
  at: Date = new Date(),
): string {
  const ext = livePreviewFrameExtension(mime);
  const stamp = at.toISOString().replace(/[:.]/g, '-').slice(0, 19);
  return `waddle_live_preview_${displayId}_${stamp}.${ext}`;
}

export function downloadLivePreviewFrameToBrowser(
  frame: LivePreviewFrame,
  displayId: string,
  at: Date = new Date(),
): void {
  const blob = new Blob([frame.payload], { type: frame.mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = buildLivePreviewFrameFilename(displayId, frame.mime, at);
  a.click();
  URL.revokeObjectURL(url);
}
