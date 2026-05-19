import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { catalogListItemFromRaw } from './parseCatalogItem';
import { catalogListPath } from './paths';
import type { CatalogKind, CatalogListItem } from './types';

export async function listCatalogItems(
  kind: CatalogKind,
  display: SavedDisplay,
): Promise<CatalogListItem[]> {
  const res = await apiJson<{ items: unknown[] }>(display, catalogListPath(kind));
  const items: CatalogListItem[] = [];
  for (const raw of res.items ?? []) {
    if (raw && typeof raw === 'object') {
      const row = catalogListItemFromRaw(kind, raw as Record<string, unknown>);
      if (row) items.push(row);
    }
  }
  items.sort((a, b) => a.label.localeCompare(b.label));
  return items;
}

export async function catalogItemExists(
  kind: CatalogKind,
  display: SavedDisplay,
  id: string,
): Promise<boolean> {
  const items = await listCatalogItems(kind, display);
  return items.some((item) => item.id === id);
}
