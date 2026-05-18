import { apiJson, type ApiError } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

export type OverlayBlobUploadResult = {
  blob_key: string;
};

const MAX_BYTES = 4 * 1024 * 1024;

/** Uploads one image for `falling_images` overlay config (`overlays.write`). */
export async function uploadOverlayImageBlob(
  display: SavedDisplay,
  file: File,
): Promise<OverlayBlobUploadResult> {
  if (file.size > MAX_BYTES) {
    throw new Error('Image must be 4 MB or smaller.');
  }
  const mime = (file.type || 'image/png').split(';')[0]!.trim().toLowerCase();
  if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(mime)) {
    throw new Error('Use JPEG, PNG, WebP, or GIF.');
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
