import { uniqueInterestSlug } from '@/util/interestSlug';

/** Slugify a catalog label (matches [catalog_id_allocation.dart] digit prefixes). */
export function slugifyCatalogLabel(source: string, digitPrefix: string): string {
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
    return `${digitPrefix}${normalized}`.slice(0, 63);
  }
  return normalized;
}

function catalogIdFromLabel(
  label: string,
  existingIds: Iterable<string>,
  digitPrefix: string,
): string {
  const base = slugifyCatalogLabel(label, digitPrefix);
  if (!base) return '';
  return uniqueInterestSlug(base, existingIds);
}

export function screenIdFromLabel(label: string, existingIds: Iterable<string>): string {
  return catalogIdFromLabel(label, existingIds, 's_');
}

export function tickerTapeIdFromLabel(label: string, existingIds: Iterable<string>): string {
  return catalogIdFromLabel(label, existingIds, 't_');
}

export function overlayIdFromLabel(label: string, existingIds: Iterable<string>): string {
  return catalogIdFromLabel(label, existingIds, 'o_');
}
