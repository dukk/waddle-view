import { applySortOrder, type ServerSortOrder } from '@/util/dataViewColumnSort';

export type SortOption<T> = {
  id: string;
  label: string;
  compare: (a: T, b: T) => number;
};

export function normalizeSearchQuery(query: string): string {
  return query.trim().toLowerCase();
}

export function filterBySearch<T>(
  items: readonly T[],
  query: string,
  matches: (item: T, normalizedQuery: string) => boolean,
): T[] {
  const q = normalizeSearchQuery(query);
  if (!q) return [...items];
  return items.filter((item) => matches(item, q));
}

export function sortByOption<T>(items: readonly T[], option: SortOption<T> | undefined): T[] {
  if (!option) return [...items];
  return [...items].sort(option.compare);
}

export function applyClientListPipeline<T>(params: {
  items: readonly T[];
  search: string;
  searchMatches: (item: T, normalizedQuery: string) => boolean;
  sortOptions: readonly SortOption<T>[];
  sortId: string;
  /** When set, re-applies asc/desc to the selected field compare (for column + Order toolbar). */
  order?: ServerSortOrder;
}): T[] {
  const filtered = filterBySearch(params.items, params.search, params.searchMatches);
  const base =
    params.sortOptions.find((o) => o.id === params.sortId) ?? params.sortOptions[0];
  if (!base) return filtered;
  const sortOption: SortOption<T> =
    params.order != null
      ? {
          ...base,
          compare: (a, b) => applySortOrder(base.compare(a, b), params.order!),
        }
      : base;
  return sortByOption(filtered, sortOption);
}
