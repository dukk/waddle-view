import { isDisplayProxyAuthEnabled } from '@/api/displayAuthMode';
import { displayProxyFetch } from '@/api/displayProxy';
import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { loadSession } from '@/storage/sessions';
import { extractOverlayBlobKeys } from '@/util/extractOverlayBlobKeys';

export async function remapOverlayBlobKeys(
  source: SavedDisplay,
  target: SavedDisplay,
  configJson: unknown,
): Promise<unknown> {
  const keys = extractOverlayBlobKeys(configJson);
  if (keys.length === 0) {
    return configJson;
  }
  const keyMap = new Map<string, string>();
  for (const key of keys) {
    const bytes = await fetchBlobBytes(source, key);
    if (!bytes) {
      throw new Error(`Could not read blob "${key}" from source display.`);
    }
    const uploaded = await uploadBlobBytes(target, bytes.data, bytes.mime);
    keyMap.set(key, uploaded.blob_key);
  }
  return replaceBlobKeysInValue(configJson, keyMap);
}

type BlobBytes = {
  data: Uint8Array;
  mime: string;
};

async function fetchBlobBytes(
  display: SavedDisplay,
  blobKey: string,
): Promise<BlobBytes | null> {
  const session = loadSession(display.id);
  const authMode = isDisplayProxyAuthEnabled();
  if (!session && !authMode) {
    return null;
  }
  const path = `/v1/media/blob-by-key?key=${encodeURIComponent(blobKey)}`;
  const res = await displayProxyFetch(
    path,
    {
      method: 'GET',
      headers: session ? { Authorization: `Bearer ${session.apiKey}` } : undefined,
    },
    {
      display,
      omitUrlWhenAuth: authMode,
    },
  );
  if (!res.ok) {
    return null;
  }
  const buf = await res.arrayBuffer();
  const mime = res.headers.get('content-type') ?? 'application/octet-stream';
  return { data: new Uint8Array(buf), mime };
}

async function uploadBlobBytes(
  display: SavedDisplay,
  bytes: Uint8Array,
  mime: string,
): Promise<{ blob_key: string }> {
  let binary = '';
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]!);
  }
  const bytesBase64 = btoa(binary);
  return apiJson<{ blob_key: string }>(display, '/v1/display/overlays/blobs', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ bytes_base64: bytesBase64, content_type: mime }),
  });
}

function replaceBlobKeysInValue(
  value: unknown,
  keyMap: Map<string, string>,
): unknown {
  if (value == null) return value;
  if (Array.isArray(value)) {
    return value.map((item) => replaceBlobKeysInValue(item, keyMap));
  }
  if (typeof value !== 'object') return value;
  const obj = { ...(value as Record<string, unknown>) };
  if (typeof obj.image_blob_key === 'string') {
    const mapped = keyMap.get(obj.image_blob_key.trim());
    if (mapped) obj.image_blob_key = mapped;
  }
  if (Array.isArray(obj.image_blob_keys)) {
    obj.image_blob_keys = obj.image_blob_keys.map((entry) => {
      if (typeof entry !== 'string') return entry;
      return keyMap.get(entry.trim()) ?? entry;
    });
  }
  for (const [k, v] of Object.entries(obj)) {
    if (k === 'image_blob_key' || k === 'image_blob_keys') continue;
    obj[k] = replaceBlobKeysInValue(v, keyMap);
  }
  return obj;
}
