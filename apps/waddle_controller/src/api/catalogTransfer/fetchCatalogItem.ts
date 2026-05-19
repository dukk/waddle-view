import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { parseCatalogPayload } from './parseCatalogItem';
import { catalogListPath } from './paths';
import type { CatalogKind, CatalogPayload } from './types';

export async function fetchCatalogItem(
  kind: CatalogKind,
  display: SavedDisplay,
  itemId: string,
): Promise<CatalogPayload | null> {
  const res = await apiJson<{ items: unknown[] }>(display, catalogListPath(kind));
  for (const raw of res.items ?? []) {
    if (!raw || typeof raw !== 'object') continue;
    const record = raw as Record<string, unknown>;
    const id = typeof record.id === 'string' ? record.id.trim() : '';
    if (id !== itemId) continue;
    return parseCatalogPayload(kind, record);
  }
  return null;
}
