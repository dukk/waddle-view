import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  applyClientListPipeline,
  type SortOption,
} from '@/util/clientListPipeline';
import {
  DATA_VIEW_DEFAULT_PAGE_SIZE,
  paginateList,
  type PaginatedList,
} from '@/util/listPagination';

export type UseClientDataViewParams<T> = {
  items: readonly T[];
  sortOptions: readonly SortOption<T>[];
  defaultSortId?: string;
  searchMatches: (item: T, normalizedQuery: string) => boolean;
  initialPageSize?: number;
};

export type UseClientDataViewResult<T> = {
  search: string;
  setSearch: (value: string) => void;
  sortId: string;
  setSortId: (value: string) => void;
  page: number;
  setPage: (value: number) => void;
  pageSize: number;
  setPageSize: (value: number) => void;
  resetPage: () => void;
  filteredTotal: number;
  paginated: PaginatedList<T>;
  allFilteredSorted: T[];
};

export function useClientDataView<T>(params: UseClientDataViewParams<T>): UseClientDataViewResult<T> {
  const defaultSortId = params.defaultSortId ?? params.sortOptions[0]?.id ?? '';
  const [search, setSearchState] = useState('');
  const [sortId, setSortIdState] = useState(defaultSortId);
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

  const setSortId = useCallback(
    (value: string) => {
      setSortIdState(value);
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

  const allFilteredSorted = useMemo(
    () =>
      applyClientListPipeline({
        items: params.items,
        search,
        searchMatches: params.searchMatches,
        sortOptions: params.sortOptions,
        sortId: sortId || defaultSortId,
      }),
    [params.items, params.searchMatches, params.sortOptions, search, sortId, defaultSortId],
  );

  const paginated = useMemo(
    () => paginateList(allFilteredSorted, page, pageSize),
    [allFilteredSorted, page, pageSize],
  );

  useEffect(() => {
    if (page !== paginated.page) {
      setPageState(paginated.page);
    }
  }, [page, paginated.page]);

  useEffect(() => {
    if (!params.sortOptions.some((o) => o.id === sortId) && defaultSortId) {
      setSortIdState(defaultSortId);
    }
  }, [params.sortOptions, sortId, defaultSortId]);

  return {
    search,
    setSearch,
    sortId: sortId || defaultSortId,
    setSortId,
    page,
    setPage,
    pageSize,
    setPageSize,
    resetPage,
    filteredTotal: allFilteredSorted.length,
    paginated,
    allFilteredSorted,
  };
}
