export function slugifyInterestSource(source: string): string {
  const normalized = source
    .trim()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .replace(/_+/g, '_')
    .slice(0, 63);
  if (!normalized) return '';
  if (!/^[a-z]/.test(normalized)) {
    return `i_${normalized}`.slice(0, 63);
  }
  return normalized;
}

export function uniqueInterestSlug(base: string, existingIds: Iterable<string>): string {
  const trimmed = base.trim();
  if (!trimmed) return '';
  const ids = new Set(existingIds);
  if (!ids.has(trimmed)) return trimmed;
  for (let n = 2; n < 10_000; n++) {
    const suffix = `_${n}`;
    const candidate = trimmed.slice(0, Math.max(1, 63 - suffix.length)) + suffix;
    if (!ids.has(candidate)) return candidate;
  }
  return `${trimmed.slice(0, 48)}_${Date.now()}`;
}

export function weatherLocationInterestId(name: string, existingIds: Iterable<string>): string {
  return uniqueInterestSlug(slugifyInterestSource(name), existingIds);
}

export function rssFeedInterestId(feedName: string, existingIds: Iterable<string>): string {
  return uniqueInterestSlug(slugifyInterestSource(feedName), existingIds);
}

export function stockSymbolInterestId(symbol: string, existingIds: Iterable<string>): string {
  return uniqueInterestSlug(slugifyInterestSource(symbol), existingIds);
}
