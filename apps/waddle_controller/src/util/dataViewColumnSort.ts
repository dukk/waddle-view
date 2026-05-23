import type { SortOption } from '@/util/clientListPipeline';

export type ServerSortOrder = 'asc' | 'desc';

export type ColumnSortField<T> = {
  id: string;
  label: string;
  compare: (a: T, b: T) => number;
};

/** Toolbar labels for Sort dropdown (compare fns live in column sort fields). */
export function columnSortToolbarOptions<T>(
  fields: readonly ColumnSortField<T>[],
): { id: string; label: string }[] {
  return fields.map((f) => ({ id: f.id, label: f.label }));
}

/** Build SortOption[]; pass `order` to applyClientListPipeline for asc/desc. */
export function buildColumnSortOptions<T>(
  fields: readonly ColumnSortField<T>[],
): SortOption<T>[] {
  return fields.map((field) => ({
    id: field.id,
    label: field.label,
    compare: field.compare,
  }));
}

export function compareLocale(a: string, b: string): number {
  return a.localeCompare(b, undefined, { sensitivity: 'base' });
}

export function compareNumber(a: number, b: number): number {
  return a - b;
}

export function compareBool(a: boolean, b: boolean): number {
  return Number(a) - Number(b);
}

export function applySortOrder(delta: number, order: ServerSortOrder): number {
  return order === 'desc' ? -delta : delta;
}

export function invertCompare<T>(compare: (a: T, b: T) => number): (a: T, b: T) => number {
  return (a, b) => -compare(a, b);
}

/** Secondary compare when primary keys tie (e.g. stable sort by internal id — not exposed in toolbar). */
export function tieBreakLocale(primary: number, aId: string, bId: string): number {
  return primary !== 0 ? primary : compareLocale(aId, bId);
}
