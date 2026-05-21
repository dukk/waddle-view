import { useCallback, useMemo, useState } from 'react';
import { DATA_VIEW_DEFAULT_PAGE_SIZE } from '@/util/listPagination';

export type ServerSortOrder = 'asc' | 'desc';

export type UseServerDataViewParams = {
  defaultSort?: string;
  defaultOrder?: ServerSortOrder;
  initialPageSize?: number;
};

export type UseServerDataViewResult = {
  search: string;
  setSearch: (value: string) => void;
  sort: string;
  setSort: (value: string) => void;
  order: ServerSortOrder;
  setOrder: (value: ServerSortOrder) => void;
  page: number;
  setPage: (value: number) => void;
  pageSize: number;
  setPageSize: (value: number) => void;
  offset: number;
  resetPage: () => void;
  query: {
    q: string | null;
    sort: string | undefined;
    order: ServerSortOrder;
    limit: number;
    offset: number;
  };
};

export function useServerDataView(params: UseServerDataViewParams = {}): UseServerDataViewResult {
  const [search, setSearchState] = useState('');
  const [sort, setSortState] = useState(params.defaultSort ?? '');
  const [order, setOrderState] = useState<ServerSortOrder>(params.defaultOrder ?? 'asc');
  const [page, setPageState] = useState(0);
  const [pageSize, setPageSizeState] = useState(
    params.initialPageSize ?? DATA_VIEW_DEFAULT_PAGE_SIZE,
  );

  const resetPage = useCallback(() => {
    setPageState(0);
  }, []);

  const setSearch = useCallback(
    (value: string) => {
      setSearchState(value);
      resetPage();
    },
    [resetPage],
  );

  const setSort = useCallback(
    (value: string) => {
      setSortState(value);
      resetPage();
    },
    [resetPage],
  );

  const setOrder = useCallback(
    (value: ServerSortOrder) => {
      setOrderState(value);
      resetPage();
    },
    [resetPage],
  );

  const setPage = useCallback((value: number) => {
    setPageState(value);
  }, []);

  const setPageSize = useCallback(
    (value: number) => {
      setPageSizeState(value);
      resetPage();
    },
    [resetPage],
  );

  const offset = page * pageSize;

  const query = useMemo(
    () => ({
      q: search.trim() || null,
      sort: sort || undefined,
      order,
      limit: pageSize,
      offset,
    }),
    [search, sort, order, pageSize, offset],
  );

  return {
    search,
    setSearch,
    sort,
    setSort,
    order,
    setOrder,
    page,
    setPage,
    pageSize,
    setPageSize,
    offset,
    resetPage,
    query,
  };
}
