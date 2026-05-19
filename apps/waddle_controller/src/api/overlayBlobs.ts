import { apiJson, type ApiError } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

export type OverlayBlobUploadResult = {
  blob_key: string;
};

const MAX_BYTES = 4 * 1024 * 1024;

export const OVERLAY_BLOB_UPLOAD_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/svg+xml',
] as const;

/** Resolves a MIME type for overlay image uploads (matches display REST validation). */
export function resolveOverlayBlobUploadMime(file: File): string {
  const fromType = (file.type || '').split(';')[0]!.trim().toLowerCase();
  if (fromType) {
    return fromType;
  }
  const name = file.name.toLowerCase();
  if (name.endsWith('.svg')) return 'image/svg+xml';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.gif')) return 'image/gif';
  return 'image/png';
}

/** Uploads one image for `falling_images` overlay config (`overlays.write`). */
export async function uploadOverlayImageBlob(
  display: SavedDisplay,
  file: File,
): Promise<OverlayBlobUploadResult> {
  if (file.size > MAX_BYTES) {
    throw new Error('Image must be 4 MB or smaller.');
  }
  const mime = resolveOverlayBlobUploadMime(file);
  if (!(OVERLAY_BLOB_UPLOAD_MIME_TYPES as readonly string[]).includes(mime)) {
    throw new Error('Use JPEG, PNG, WebP, GIF, or SVG.');
  }
  const buffer = await file.arrayBuffer();
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]!);
  }
  const bytesBase64 = btoa(binary);
  return apiJson<OverlayBlobUploadResult>(display, '/v1/display/overlays/blobs', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ bytes_base64: bytesBase64, content_type: mime }),
  });
}

export function isOverlayBlobApiError(err: unknown): err is ApiError {
  return typeof err === 'object' && err !== null && 'status' in err;
}
