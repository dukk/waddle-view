---
name: controller-data-view
description: >-
  waddle_controller list/catalog page UX: DataViewToolbar (card/table, reload,
  search, sort, paging). Use when adding or editing operator list pages.
disable-model-invocation: true
---

# Controller data view UX

Repo constraints: [AGENTS.md](../../../AGENTS.md); rule summary in [waddle-controller.mdc](../../rules/waddle-controller.mdc).

## When to apply

Any **list or catalog page** under `apps/waddle_controller/src/pages/` that shows a collection of rows from the display API or BFF (Screens, Integrations, Data, Activity, Users, etc.).

**Exempt** (forms, single widgets, auth): Remote, Account, Display settings (except nested tables), login/bootstrap/join.

## Checklist

1. **Layout**: `useListLayoutPreference('<page-key>')` with a key in [`listLayoutPreference.ts`](../../../apps/waddle_controller/src/storage/listLayoutPreference.ts). Default **table** for `data` and `activity` only.
2. **Toolbar**: [`DataViewToolbar`](../../../apps/waddle_controller/src/components/dataView/DataViewToolbar.tsx): search, sort, reload, card/table toggle; optional `filterSlot` for extra filters (channel, category chips, column filters).
3. **Client lists**: [`useClientDataView`](../../../apps/waddle_controller/src/hooks/useClientDataView.ts) + [`DataViewPagination`](../../../apps/waddle_controller/src/components/dataView/DataViewPagination.tsx); define column sort fields via [`dataViewColumnSort.ts`](../../../apps/waddle_controller/src/util/dataViewColumnSort.ts) (`buildColumnSortOptions`, `columnSortToolbarOptions`), set `useSortOrder: true`, and wire toolbar `order` / `onOrderChange`.
4. **Server-paged lists**: [`useServerDataView`](../../../apps/waddle_controller/src/hooks/useServerDataView.ts); pass `query` into API params (`q`, `sort`, `order`, `limit`, `offset`); refetch when controls change; reset section pages on filter/sort change.
5. **Reload**: wire `onReload` to the page `load` function; `reloadDisabled` while `useDisplayRefresh().loading` (or page `loading` for BFF-only pages).
6. **Empty states**: [`DataViewEmptyState`](../../../apps/waddle_controller/src/components/dataView/DataViewEmptyState.tsx) for "no data" vs "no matches".
7. **Both layouts**: implement **card** and **table** branches over the same `displayRows` / `paginated.items`.
8. **Sort labels**: offer a toolbar sort option for every **visible data column** (not Actions / row-action switches / rich preview thumbnails unless a scalar proxy exists). Use human column titles. Do **not** add "ID" sort options; internal ids may still be used in `searchMatches` or `tieBreakLocale` tie-breakers.

Reset page index when search, sort, or filter changes.

## Toolbar layout

`[Search] [filterSlot...] [Sort] [Order?] [Reload] [Card|Table] [page actions]`

Pagination below the list (card or table).

## Client list template

```tsx
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewEmptyState } from '@/components/dataView/DataViewEmptyState';
import { useClientDataView } from '@/hooks/useClientDataView';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import {
  buildColumnSortOptions,
  columnSortToolbarOptions,
  compareLocale,
  tieBreakLocale,
  type ColumnSortField,
} from '@/util/dataViewColumnSort';

const SORT_FIELDS: ColumnSortField<Row>[] = [
  {
    id: 'name',
    label: 'Name',
    compare: (a, b) => tieBreakLocale(compareLocale(a.name, b.name), a.id, b.id),
  },
];
const sortOptions = buildColumnSortOptions(SORT_FIELDS);
const sortToolbar = columnSortToolbarOptions(SORT_FIELDS);

const { layout, setLayout } = useListLayoutPreference('my-page');
const dataView = useClientDataView({
  items: rows,
  sortOptions,
  defaultSortId: 'name',
  useSortOrder: true,
  searchMatches: (row, q) => row.name.toLowerCase().includes(q),
});
const displayRows = dataView.paginated.items;

<DataViewToolbar
  layout={layout}
  onLayoutChange={setLayout}
  search={dataView.search}
  onSearchChange={dataView.setSearch}
  sortOptions={sortToolbar}
  sortId={dataView.sortId}
  onSortChange={dataView.setSortId}
  order={dataView.order}
  onOrderChange={dataView.setOrder}
  onReload={() => void load()}
  reloadDisabled={loading}
/>
{/* card or table using displayRows */}
<DataViewPagination
  count={dataView.filteredTotal}
  page={dataView.paginated.page}
  pageSize={dataView.paginated.pageSize}
  onPageChange={dataView.setPage}
  onPageSizeChange={dataView.setPageSize}
/>
```

## Server-paged template (Integrations-style)

```tsx
const listControls = useServerDataView({ defaultSort: 'integration_type_label', defaultOrder: 'asc' });

// listParams: { ...listControls.query, enabled, ... }
// useEffect deps include listControls.query

<DataViewToolbar
  ...
  order={listControls.order}
  onOrderChange={listControls.setOrder}
/>
```

## Data browser note

[`DataPage`](../../../apps/waddle_controller/src/pages/DataPage.tsx) uses **server** paging per tab; toolbar search and per-column sort (via [`dataCatalogSort.ts`](../../../apps/waddle_controller/src/util/dataCatalogSort.ts)) apply to the **current page** only until catalog APIs gain `sort`/`order` query params.

## Shared utilities

- [`listPagination.ts`](../../../apps/waddle_controller/src/util/listPagination.ts): `paginateList`, default page size 25
- [`clientListPipeline.ts`](../../../apps/waddle_controller/src/util/clientListPipeline.ts): `applyClientListPipeline`, `filterBySearch`, `sortByOption` (unit-tested)
- [`dataViewColumnSort.ts`](../../../apps/waddle_controller/src/util/dataViewColumnSort.ts): `compareLocale`, `compareNumber`, `applySortOrder`, `buildColumnSortOptions`, `columnSortToolbarOptions`
- [`interestTabSort.ts`](../../../apps/waddle_controller/src/util/interestTabSort.ts): per-tab sort fields for Interests

## Verification

```bash
cd apps/waddle_controller
npm run lint
npm run test:coverage
```

Manually: toggle card/table (persists after refresh), reload refetches, filter/sort/paging reset page correctly.
