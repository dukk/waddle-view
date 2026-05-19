/** Collects overlay image blob keys from config JSON (falling_images, display settings, etc.). */
export function extractOverlayBlobKeys(config: unknown): string[] {
  const keys = new Set<string>();
  walk(config, keys);
  return [...keys].sort();
}

function walk(value: unknown, keys: Set<string>): void {
  if (value == null) return;
  if (Array.isArray(value)) {
    for (const item of value) {
      walk(item, keys);
    }
    return;
  }
  if (typeof value !== 'object') return;
  const obj = value as Record<string, unknown>;
  if (typeof obj.image_blob_key === 'string') {
    const k = obj.image_blob_key.trim();
    if (k) keys.add(k);
  }
  const list = obj.image_blob_keys;
  if (Array.isArray(list)) {
    for (const entry of list) {
      if (typeof entry === 'string') {
        const k = entry.trim();
        if (k) keys.add(k);
      }
    }
  }
  for (const v of Object.values(obj)) {
    walk(v, keys);
  }
}
