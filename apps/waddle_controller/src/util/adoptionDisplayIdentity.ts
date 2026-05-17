import { loadDisplays, normalizeBaseUrl } from '@/storage/displays';

/** Saved displays targeting the same display base URL (normalized). */
export function displaysForBaseUrl(baseUrl: string) {
  const normalized = normalizeBaseUrl(baseUrl);
  return loadDisplays().filter((d) => normalizeBaseUrl(d.baseUrl) === normalized);
}

function usedIdentifiersForBaseUrl(baseUrl: string): Set<string> {
  const used = new Set<string>();
  for (const d of displaysForBaseUrl(baseUrl)) {
    const id = d.identifier?.trim();
    if (id) used.add(id);
  }
  return used;
}

/**
 * Picks a client identifier that does not collide with other saved rows for this display.
 * Reuses [stem] for the first adoption on a URL; adds `-{role}` (and numeric suffixes) when needed.
 */
export function suggestAdoptionIdentifier(
  baseUrl: string,
  role: string,
  stem: string,
): string {
  const trimmedStem = stem.trim();
  if (!trimmedStem) {
    return role;
  }
  const used = usedIdentifiersForBaseUrl(baseUrl);
  if (used.size === 0 && !used.has(trimmedStem)) {
    return trimmedStem;
  }
  let candidate = `${trimmedStem}-${role}`;
  let suffix = 2;
  while (used.has(candidate)) {
    candidate = `${trimmedStem}-${role}-${suffix}`;
    suffix += 1;
  }
  return candidate;
}

/** Default menu label when the operator leaves Label blank. */
export function suggestDisplayLabel(
  baseUrl: string,
  role: string,
  customLabel?: string,
): string {
  const trimmed = customLabel?.trim();
  if (trimmed) return trimmed;
  const normalized = normalizeBaseUrl(baseUrl);
  const peers = displaysForBaseUrl(baseUrl);
  if (peers.length === 0) {
    return normalized;
  }
  try {
    const host = new URL(normalized).host;
    return `${host} (${role})`;
  } catch {
    return `${normalized} (${role})`;
  }
}
