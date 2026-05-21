export type PaginatedList<T> = {
  items: T[];
  total: number;
  page: number;
  pageCount: number;
  pageSize: number;
};

/** Client-side page slice; clamps `page` when the list shrinks. */
export function paginateList<T>(
  items: readonly T[],
  page: number,
  pageSize: number,
): PaginatedList<T> {
  const total = items.length;
  const safePageSize = pageSize > 0 ? pageSize : Math.max(total, 1);
  const pageCount = Math.max(1, Math.ceil(total / safePageSize));
  const safePage = Math.min(Math.max(0, page), pageCount - 1);
  const start = safePage * safePageSize;
  return {
    items: items.slice(start, start + safePageSize),
    total,
    page: safePage,
    pageCount,
    pageSize: safePageSize,
  };
}

export const DATA_VIEW_ROWS_PER_PAGE_OPTIONS = [10, 25, 50] as const;
export const DATA_VIEW_DEFAULT_PAGE_SIZE = 25;
