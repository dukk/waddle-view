import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  Alert,
  Box,
  Button,
  Chip,
  FormControl,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  Switch,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tabs,
  TextField,
  Typography,
} from '@mui/material';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { useDisplayFormat } from '@/context/DisplayFormatContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { sortByOption } from '@/util/clientListPipeline';
import { applySortOrder, type ServerSortOrder } from '@/util/dataViewColumnSort';
import {
  dataSortOptionsForKind,
  dataSortToolbarForKind,
  defaultDataSortIdForKind,
  type DataCatalogKind,
} from '@/util/dataCatalogSort';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { useConfirmDialog } from '@/hooks/useConfirmDialog';
import { AlertEntryDialog } from '@/components/data/AlertEntryDialog';
import { CatalogBlobMedia } from '@/components/data/CatalogBlobMedia';
import { DataCatalogCard } from '@/components/data/DataCatalogCard';
import { ManualEntryDialog } from '@/components/data/ManualEntryDialog';
import { fetchIntegrationAccounts } from '@/api/integrationAccounts';
import { listIntegrations } from '@/api/integrations';
import {
  alertLifecycleLabel,
  alertLifecycleStatus,
  alertSeverityLabel,
  alertSourceLabel,
  icalFeedsByIdFromConfig,
  newsSourceLabel,
  parseCalendarEventSource,
} from '@/util/catalogDisplayLabels';
import { alertSeverityIconComponent } from '@/util/alertSeverityIcon';
import { parseIcalCalendarConfig } from '@/util/icalCalendarConfig';
import { integrationDisplayName } from '@/util/integrationDisplayName';
import { isManualEntryKind } from '@/util/manualEntryApi';
import {
  type CatalogDataKind,
  type DataCatalogIntegrationFilter,
  buildDataCatalogSearchParams,
  catalogCategoryOptionsParams,
  catalogDataKindForIntegrationType,
  catalogFilterParamsForIntegration,
  integrationFilterFromSearchParams,
  isCatalogKindWithCategoryFilter,
  parseDataCatalogSearchParams,
} from '@/util/integrationDataCatalog';

type DataKind =
  | 'calendar_events'
  | 'jokes'
  | 'trivia'
  | 'news'
  | 'photos'
  | 'quoterism_quotes'
  | 'videos'
  | 'stocks'
  | 'weather'
  | 'weather_alerts'
  | 'dashboard_alerts'
  | 'tasks';

type Paginated<T> = { items: T[]; total: number; limit?: number; offset?: number };

/** Tabs in alphabetical order by label. */
const DATA_TABS: { kind: DataKind; label: string }[] = [
  { kind: 'dashboard_alerts', label: 'Alerts' },
  { kind: 'calendar_events', label: 'Calendar' },
  { kind: 'jokes', label: 'Jokes' },
  { kind: 'news', label: 'News' },
  { kind: 'photos', label: 'Photos' },
  { kind: 'quoterism_quotes', label: 'Quotes' },
  { kind: 'stocks', label: 'Stocks' },
  { kind: 'tasks', label: 'Tasks' },
  { kind: 'trivia', label: 'Trivia' },
  { kind: 'videos', label: 'Videos' },
  { kind: 'weather', label: 'Weather' },
  { kind: 'weather_alerts', label: 'Weather alerts' },
];

function defaultRowsForKind(kind: DataKind): number {
  if (kind === 'videos') {
    return 5;
  }
  if (kind === 'news' || kind === 'photos' || kind === 'weather') {
    return 10;
  }
  return 25;
}

function catalogPath(kind: DataKind): string {
  switch (kind) {
    case 'calendar_events':
      return '/v1/catalog/calendar-events';
    case 'jokes':
      return '/v1/catalog/jokes';
    case 'trivia':
      return '/v1/catalog/trivia';
    case 'news':
      return '/v1/catalog/rss-articles';
    case 'photos':
      return '/v1/catalog/photos';
    case 'quoterism_quotes':
      return '/v1/catalog/quoterism-quotes';
    case 'videos':
      return '/v1/catalog/videos';
    case 'stocks':
      return '/v1/catalog/stock-quotes';
    case 'weather':
      return '/v1/catalog/weather-current';
    case 'weather_alerts':
      return '/v1/catalog/weather-alerts';
    case 'dashboard_alerts':
      return '/v1/catalog/alerts';
    case 'tasks':
      return '/v1/catalog/tasks';
  }
}

function canSuppress(kind: DataKind): boolean {
  return (
    kind === 'jokes' ||
    kind === 'trivia' ||
    kind === 'news' ||
    kind === 'photos' ||
    kind === 'videos' ||
    kind === 'quoterism_quotes'
  );
}

function contentPatchPath(kind: DataKind, id: string): string | null {
  switch (kind) {
    case 'jokes':
      return `/v1/content/jokes/${encodeURIComponent(id)}`;
    case 'trivia':
      return `/v1/content/trivia/${encodeURIComponent(id)}`;
    case 'news':
      return `/v1/content/rss-articles/${encodeURIComponent(id)}`;
    case 'photos':
      return `/v1/content/photos/${encodeURIComponent(id)}`;
    case 'videos':
      return `/v1/content/videos/${encodeURIComponent(id)}`;
    case 'quoterism_quotes':
      return `/v1/content/quoterism-quotes/${encodeURIComponent(id)}`;
    default:
      return null;
  }
}

function contentDeletePath(kind: DataKind, row: Record<string, unknown>): string | null {
  switch (kind) {
    case 'jokes':
    case 'trivia':
    case 'news':
    case 'photos':
    case 'videos':
    case 'quoterism_quotes':
    case 'calendar_events': {
      const id = String(row.id ?? '').trim();
      if (!id) return null;
      if (kind === 'jokes') return `/v1/content/jokes/${encodeURIComponent(id)}`;
      if (kind === 'trivia') return `/v1/content/trivia/${encodeURIComponent(id)}`;
      if (kind === 'news') return `/v1/content/rss-articles/${encodeURIComponent(id)}`;
      if (kind === 'photos') return `/v1/content/photos/${encodeURIComponent(id)}`;
      if (kind === 'videos') return `/v1/content/videos/${encodeURIComponent(id)}`;
      if (kind === 'quoterism_quotes') {
        return `/v1/content/quoterism-quotes/${encodeURIComponent(id)}`;
      }
      return `/v1/content/calendar-events/${encodeURIComponent(id)}`;
    }
    case 'stocks': {
      const symbolId = String(row.symbol_id ?? '').trim();
      return symbolId ? `/v1/content/stock-quotes/${encodeURIComponent(symbolId)}` : null;
    }
    case 'weather': {
      const locationId = String(row.location_id ?? '').trim();
      return locationId
        ? `/v1/content/weather-current/${encodeURIComponent(locationId)}`
        : null;
    }
    case 'weather_alerts': {
      const locationId = String(row.location_id ?? '').trim();
      const nwsAlertId = String(row.nws_alert_id ?? '').trim();
      if (!locationId || !nwsAlertId) return null;
      return `/v1/content/weather-alerts/${encodeURIComponent(locationId)}/${encodeURIComponent(nwsAlertId)}`;
    }
    case 'dashboard_alerts': {
      const id = row.id;
      if (id == null || id === '') return null;
      return `/v1/alerts/${encodeURIComponent(String(id))}`;
    }
    case 'tasks':
      return null;
  }
}

function deleteRowSummary(kind: DataKind, row: Record<string, unknown>): string {
  switch (kind) {
    case 'jokes':
      return String(row.setup ?? row.id ?? 'joke');
    case 'quoterism_quotes':
      return String(row.text ?? row.id ?? 'quote');
    case 'trivia':
      return String(row.question ?? row.id ?? 'trivia');
    case 'news':
      return String(row.title ?? row.id ?? 'article');
    case 'photos':
    case 'videos':
      return String(row.alt_text ?? row.id ?? kind);
    case 'stocks':
      return String(row.symbol ?? row.symbol_id ?? 'quote');
    case 'weather':
      return String(row.location_name ?? row.location_id ?? 'weather');
    case 'weather_alerts':
      return String(row.event ?? row.nws_alert_id ?? 'alert');
    case 'dashboard_alerts':
      return String(row.title ?? row.id ?? 'alert');
    case 'calendar_events':
      return String(row.title ?? row.id ?? 'event');
    case 'tasks':
      return String(row.title ?? row.id ?? 'task');
  }
}

function categoryLabel(categories: { id: string; label: string }[], id: string): string {
  return categories.find((c) => c.id === id)?.label ?? id;
}

function calendarEventWhen(
  ms: unknown,
  allDay: boolean,
  formatDateTime: (d: Date) => string,
): string {
  if (ms == null || ms === '') return '—';
  const d = new Date(Number(ms));
  if (allDay) {
    return `${d.toLocaleDateString()} (all day)`;
  }
  return formatDateTime(d);
}

function calendarCategoryCell(
  row: Record<string, unknown>,
  categories: { id: string; label: string }[],
): string {
  const ids = Array.isArray(row.category_ids) ? (row.category_ids as string[]) : [];
  const primary = String(row.category_id ?? '');
  const allIds = ids.length > 0 ? ids : primary ? [primary] : [];
  if (allIds.length === 0) return '—';
  const labels = allIds.map((id) => categoryLabel(categories, id));
  if (labels.length === 1) return labels[0]!;
  return `${labels[0]} (+${labels.length - 1})`;
}

function integrationCell(row: Record<string, unknown>): string {
  const raw = row.integration_type;
  if (raw == null || typeof raw !== 'string' || !raw.trim()) {
    return '—';
  }
  return integrationDisplayName(raw.trim());
}

/** Stable list keys: weather / weather-alerts catalog rows omit `id`, so `${kind}-` would duplicate and break row reconciliation. */
function catalogRowKey(kind: DataKind, row: Record<string, unknown>, index: number): string {
  switch (kind) {
    case 'stocks':
      return `stk-${String(row.symbol_id ?? '')}-${index}`;
    case 'weather':
      return `wx-${String(row.location_id ?? '')}-${String(row.observed_at_ms ?? '')}-${index}`;
    case 'weather_alerts':
      return `alt-${String(row.location_id ?? '')}-${String(row.nws_alert_id ?? '')}-${index}`;
    case 'dashboard_alerts':
      return `da-${String(row.id ?? '')}-${index}`;
    default: {
      const id = String(row.id ?? '');
      return `${kind}-${id || `idx-${index}`}`;
    }
  }
}

function rowMatchesToolbarSearch(row: Record<string, unknown>, q: string): boolean {
  for (const value of Object.values(row)) {
    if (value == null) continue;
    if (typeof value === 'string' && value.toLowerCase().includes(q)) return true;
    if (typeof value === 'number' && String(value).includes(q)) return true;
  }
  return false;
}

function dataKindFromSearchParams(params: URLSearchParams): DataKind {
  const parsed = parseDataCatalogSearchParams(params);
  if (parsed.kind && DATA_TABS.some((t) => t.kind === parsed.kind)) {
    return parsed.kind;
  }
  return 'jokes';
}

export function DataPage() {
  const { confirm, ConfirmDialogHost } = useConfirmDialog();
  const { active } = useDisplay();
  const { formatDateTime } = useDisplayFormat();
  const { hasPermission } = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const { layout, setLayout } = useListLayoutPreference('data');
  const canModerate = hasPermission('content.moderate');
  const canBrowseData = canModerate || hasPermission('content.catalog_read');
  const canCuratorWrite = hasPermission('curator.write');
  const canAlertsWrite = hasPermission('alerts.write');

  const initialKind = dataKindFromSearchParams(searchParams);
  const [kind, setKind] = useState<DataKind>(initialKind);
  const [integrationFilter, setIntegrationFilter] = useState<DataCatalogIntegrationFilter | null>(
    () => integrationFilterFromSearchParams(searchParams),
  );
  const canAddManualEntry = canCuratorWrite && isManualEntryKind(kind);
  const canAddAlert = canAlertsWrite && kind === 'dashboard_alerts';
  const [toolbarSearch, setToolbarSearch] = useState('');
  const [dataSortId, setDataSortId] = useState(() => defaultDataSortIdForKind(initialKind as DataCatalogKind));
  const [dataSortOrder, setDataSortOrder] = useState<ServerSortOrder>('desc');
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(() => defaultRowsForKind(initialKind));
  const [suppressed, setSuppressed] = useState<'all' | 'true' | 'false'>('all');
  const [categoryId, setCategoryId] = useState('');
  const [feedId, setFeedId] = useState('');
  const [locationId, setLocationId] = useState('');
  const [boardKey, setBoardKey] = useState('');

  const [rows, setRows] = useState<Record<string, unknown>[]>([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const { loading: metadataLoading, wrapRefresh: wrapMetadataRefresh } = useDisplayRefresh();
  const { loading: categoryFilterLoading, wrapRefresh: wrapCategoryFilterRefresh } =
    useDisplayRefresh();
  const { loading: catalogLoading, wrapRefresh: wrapCatalogRefresh } = useDisplayRefresh();

  const [categories, setCategories] = useState<{ id: string; label: string }[]>([]);
  const [categoryFilterOptions, setCategoryFilterOptions] = useState<
    { id: string; label: string }[]
  >([]);
  const [feeds, setFeeds] = useState<{ id: string; title: string | null; url: string }[]>([]);
  const [locations, setLocations] = useState<{ id: string; name: string }[]>([]);
  const [manualEntryOpen, setManualEntryOpen] = useState(false);
  const [alertEntryOpen, setAlertEntryOpen] = useState(false);
  const [integrationAccounts, setIntegrationAccounts] = useState<
    { id: string; label: string }[]
  >([]);
  const [icalFeedsById, setIcalFeedsById] = useState<
    Record<string, { label?: string; url: string }>
  >({});

  useEffect(() => {
    setPage(0);
    setRowsPerPage(defaultRowsForKind(kind));
    setToolbarSearch('');
    setDataSortId(defaultDataSortIdForKind(kind as DataCatalogKind));
    setDataSortOrder(kind === 'calendar_events' || kind === 'dashboard_alerts' ? 'desc' : 'asc');
  }, [kind]);

  /** Cancels stale catalog fetches so a slow tab (e.g. weather) cannot overwrite rows after switching kind. */
  const catalogFetchAbortRef = useRef<AbortController | null>(null);
  /** Monotonic generation: late responses (or non-aborted fetches) cannot apply after a newer load started. */
  const catalogLoadGenerationRef = useRef(0);

  useEffect(() => {
    setPage(0);
  }, [suppressed, categoryId, feedId, locationId, boardKey, rowsPerPage, kind, integrationFilter]);

  useEffect(() => {
    const nextKind = dataKindFromSearchParams(searchParams);
    setKind(nextKind);
    setIntegrationFilter(integrationFilterFromSearchParams(searchParams));
  }, [searchParams]);

  const setKindAndUrl = useCallback(
    (nextKind: DataKind) => {
      setKind(nextKind);
      setIntegrationFilter(null);
      setSearchParams(buildDataCatalogSearchParams({ kind: nextKind, integrationFilter: null }), {
        replace: true,
      });
    },
    [setSearchParams],
  );

  const clearIntegrationFilter = useCallback(() => {
    setIntegrationFilter(null);
    setSearchParams(buildDataCatalogSearchParams({ kind, integrationFilter: null }), {
      replace: true,
    });
  }, [kind, setSearchParams]);

  const loadMetadata = useCallback(async () => {
    if (!active || !canBrowseData) return;
    await wrapMetadataRefresh(async () => {
      try {
        const [catRes, feedRes, locRes] = await Promise.all([
          apiJson<{ items: { id: string; label: string }[] }>(active, '/v1/curator/categories'),
          apiJson<{ items: { id: string; title: string | null; url: string }[] }>(
            active,
            '/v1/interests/rss-feeds',
          ),
          apiJson<{ items: { id: string; name: string }[] }>(
            active,
            '/v1/interests/weather-locations',
          ),
        ]);
        setCategories(catRes.items ?? []);
        setFeeds(feedRes.items ?? []);
        setLocations(locRes.items ?? []);
        const [accountsRes, integrationsRes] = await Promise.all([
          fetchIntegrationAccounts(active),
          listIntegrations(active, { limit: 200, offset: 0 }),
        ]);
        setIntegrationAccounts(
          (accountsRes.items ?? []).map((a) => ({ id: a.id, label: a.label })),
        );
        const icalRow = (integrationsRes.items ?? []).find(
          (i) => i.integration_type === 'calendar_ical',
        );
        if (icalRow?.config_json && typeof icalRow.config_json === 'object') {
          const parsed = parseIcalCalendarConfig(icalRow.config_json as Record<string, unknown>);
          setIcalFeedsById(icalFeedsByIdFromConfig(parsed.feeds));
        } else {
          setIcalFeedsById({});
        }
      } catch {
        /* optional metadata */
      }
    });
  }, [active, canBrowseData, wrapMetadataRefresh]);

  useEffect(() => {
    void loadMetadata();
  }, [loadMetadata]);

  const loadCategoryFilterOptions = useCallback(async () => {
    if (!active || !canBrowseData || !isCatalogKindWithCategoryFilter(kind)) {
      setCategoryFilterOptions([]);
      return;
    }
    await wrapCategoryFilterRefresh(async () => {
      try {
        const params = catalogCategoryOptionsParams({
          kind,
          suppressed,
          includeSuppressedFilter: canModerate && canSuppress(kind),
          integrationFilter,
        });
        const data = await apiJson<{ items: { id: string; label: string }[] }>(
          active,
          `/v1/catalog/category-options?${params.toString()}`,
        );
        const items = data.items ?? [];
        setCategoryFilterOptions(items);
        setCategoryId((prev) =>
          prev && !items.some((c) => c.id === prev) ? '' : prev,
        );
      } catch {
        setCategoryFilterOptions([]);
        setCategoryId('');
      }
    });
  }, [
    active,
    canBrowseData,
    canModerate,
    integrationFilter,
    kind,
    suppressed,
    wrapCategoryFilterRefresh,
  ]);

  useEffect(() => {
    void loadCategoryFilterOptions();
  }, [loadCategoryFilterOptions]);

  const offset = page * rowsPerPage;

  const querySuffix = useMemo(() => {
    const p = new URLSearchParams();
    p.set('limit', String(rowsPerPage));
    p.set('offset', String(offset));
    if (canModerate && canSuppress(kind) && suppressed !== 'all') p.set('suppressed', suppressed);
    if (
      categoryId &&
      (kind === 'calendar_events' ||
        kind === 'jokes' ||
        kind === 'trivia' ||
        kind === 'photos' ||
        kind === 'videos' ||
        kind === 'quoterism_quotes')
    ) {
      p.set('category', categoryId);
    }
    if (kind === 'news' && feedId) p.set('feed_id', feedId);
    if ((kind === 'weather' || kind === 'weather_alerts') && locationId) {
      p.set('location_id', locationId);
    }
    if (kind === 'tasks' && boardKey.trim()) {
      p.set('board_key', boardKey.trim());
    }
    if (
      integrationFilter &&
      catalogDataKindForIntegrationType(integrationFilter.integrationType) === kind
    ) {
      const extra = catalogFilterParamsForIntegration(kind as CatalogDataKind, {
        id: integrationFilter.integrationId,
        integration_type: integrationFilter.integrationType,
      });
      extra.forEach((value, key) => {
        p.set(key, value);
      });
    }
    const s = p.toString();
    return s ? `?${s}` : '';
  }, [
    offset,
    suppressed,
    categoryId,
    feedId,
    locationId,
    boardKey,
    kind,
    rowsPerPage,
    canModerate,
    integrationFilter,
  ]);

  useLayoutEffect(() => {
    setRows([]);
    setTotal(0);
  }, [kind]);

  const loadCatalog = useCallback(async () => {
    if (!active || !canBrowseData) return;
    catalogFetchAbortRef.current?.abort();
    const controller = new AbortController();
    catalogFetchAbortRef.current = controller;
    const myGen = ++catalogLoadGenerationRef.current;
    setError(null);
    await wrapCatalogRefresh(async () => {
      try {
        const path = `${catalogPath(kind)}${querySuffix}`;
        const data = await apiJson<Paginated<Record<string, unknown>>>(active, path, {
          signal: controller.signal,
          cache: 'no-store',
        });
        if (myGen !== catalogLoadGenerationRef.current || controller.signal.aborted) return;
        setRows(data.items ?? []);
        setTotal(typeof data.total === 'number' ? data.total : 0);
      } catch (e) {
        if (controller.signal.aborted || myGen !== catalogLoadGenerationRef.current) return;
        const msg = e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
        setError(msg);
        setRows([]);
        setTotal(0);
      }
    });
  }, [active, canBrowseData, kind, querySuffix, wrapCatalogRefresh]);

  useEffect(() => {
    void loadCatalog();
    return () => {
      catalogFetchAbortRef.current?.abort();
      catalogLoadGenerationRef.current += 1;
    };
  }, [loadCatalog]);

  const patchSuppressed = async (id: string, next: boolean) => {
    if (!canModerate || !active) return;
    const path = contentPatchPath(kind, id);
    if (!path) return;
    try {
      await apiFetch(active, path, {
        method: 'PATCH',
        body: JSON.stringify({ suppressed: next }),
      });
      await loadCatalog();
    } catch (e) {
      const msg = e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
      setError(msg);
    }
  };

  const deleteRow = useCallback(
    async (row: Record<string, unknown>) => {
      if (!canModerate || !active) return;
      const path = contentDeletePath(kind, row);
      if (!path) return;
      const summary = deleteRowSummary(kind, row);
      const ok = await confirm({
        title: 'Permanently delete?',
        message: `Permanently delete “${summary}”? This cannot be undone.`,
        confirmLabel: 'Delete',
        severity: 'error',
      });
      if (!ok) return;
      setError(null);
      try {
        await apiFetch(active, path, { method: 'DELETE' });
        await loadCatalog();
      } catch (e) {
        const msg = e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
        setError(msg);
      }
    },
    [active, canModerate, confirm, kind, loadCatalog],
  );

  const dataSortOptions = useMemo(
    () => dataSortOptionsForKind(kind as DataCatalogKind, categories),
    [kind, categories],
  );
  const dataSortToolbar = useMemo(
    () => dataSortToolbarForKind(kind as DataCatalogKind, categories),
    [kind, categories],
  );

  const displayRows = useMemo(() => {
    const q = toolbarSearch.trim().toLowerCase();
    let list = rows;
    if (q) {
      list = rows.filter((row) => rowMatchesToolbarSearch(row, q));
    }
    const sortOption = dataSortOptions.find((o) => o.id === dataSortId) ?? dataSortOptions[0];
    if (!sortOption) return list;
    const ordered = {
      ...sortOption,
      compare: (a: Record<string, unknown>, b: Record<string, unknown>) =>
        applySortOrder(sortOption.compare(a, b), dataSortOrder),
    };
    return sortByOption(list, ordered);
  }, [rows, toolbarSearch, dataSortId, dataSortOrder, dataSortOptions]);

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  if (!canBrowseData) {
    return (
      <Alert severity="info">
        The Data browser requires the <strong>content.catalog_read</strong> or{' '}
        <strong>content.moderate</strong> permission (for example power_viewer, operator, or admin). Without it,
        catalog API calls return 403.
      </Alert>
    );
  }

  const metadataFiltersBusy =
    (metadataLoading &&
      (kind === 'news' || kind === 'weather' || kind === 'weather_alerts')) ||
    (categoryFilterLoading && isCatalogKindWithCategoryFilter(kind));

  return (
    <Stack spacing={2}>
      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          Collected content browser
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Browse content stored on the active display—calendar events, jokes, news, photos, stocks,
          weather, and alerts.
          Filter and paginate each tab; with <strong>content.moderate</strong> (operator or admin role)
          you can suppress rows so they are omitted from future programs, or permanently delete a row.
        </Typography>
      </Box>
      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}
      <Paper sx={{ px: 2, pt: 1 }}>
        <Tabs
          value={kind}
          onChange={(_, v) => setKindAndUrl(v as DataKind)}
          variant="scrollable"
          scrollButtons="auto"
          sx={{ borderBottom: 1, borderColor: 'divider' }}
        >
          {DATA_TABS.map((t) => (
            <Tab key={t.kind} label={t.label} value={t.kind} />
          ))}
        </Tabs>
      </Paper>

      <DataViewToolbar
        layout={layout}
        onLayoutChange={setLayout}
        search={toolbarSearch}
        onSearchChange={setToolbarSearch}
        searchPlaceholder="Search current page…"
        sortOptions={dataSortToolbar}
        sortId={dataSortId}
        onSortChange={setDataSortId}
        order={dataSortOrder}
        onOrderChange={setDataSortOrder}
        onReload={() => void loadCatalog()}
        reloadDisabled={catalogLoading}
        reloadAriaLabel="Reload catalog data"
      >
        {canAddManualEntry && active ? (
          <Button variant="contained" onClick={() => setManualEntryOpen(true)}>
            Add
          </Button>
        ) : null}
        {canAddAlert && active ? (
          <Button variant="contained" onClick={() => setAlertEntryOpen(true)}>
            Add
          </Button>
        ) : null}
      </DataViewToolbar>

      {active && isManualEntryKind(kind) ? (
        <ManualEntryDialog
          open={manualEntryOpen}
          kind={kind}
          display={active}
          onClose={() => setManualEntryOpen(false)}
          onSaved={() => void loadCatalog()}
        />
      ) : null}

      {active && canAddAlert ? (
        <AlertEntryDialog
          open={alertEntryOpen}
          display={active}
          onClose={() => setAlertEntryOpen(false)}
          onSaved={() => void loadCatalog()}
        />
      ) : null}

      <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} flexWrap="wrap" useFlexGap>
        {canModerate && canSuppress(kind) && (
          <FormControl size="small" sx={{ minWidth: 160 }}>
            <InputLabel id="suppressed-filter">Suppressed</InputLabel>
            <Select
              labelId="suppressed-filter"
              label="Suppressed"
              value={suppressed}
              onChange={(e) => setSuppressed(e.target.value as 'all' | 'true' | 'false')}
            >
              <MenuItem value="all">All</MenuItem>
              <MenuItem value="false">Active only</MenuItem>
              <MenuItem value="true">Suppressed only</MenuItem>
            </Select>
          </FormControl>
        )}
        {isCatalogKindWithCategoryFilter(kind) && (
          <FormControl size="small" sx={{ minWidth: 180 }}>
            <InputLabel id="cat-filter">Category</InputLabel>
            <Select
              labelId="cat-filter"
              label="Category"
              value={categoryId}
              disabled={metadataFiltersBusy}
              onChange={(e) => setCategoryId(e.target.value as string)}
            >
              <MenuItem value="">Any</MenuItem>
              {categoryFilterOptions.map((c) => (
                <MenuItem key={c.id} value={c.id}>
                  {c.label}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        )}
        {kind === 'news' && (
          <FormControl size="small" sx={{ minWidth: 200 }}>
            <InputLabel id="feed-filter">Feed</InputLabel>
            <Select
              labelId="feed-filter"
              label="Feed"
              value={feedId}
              disabled={metadataFiltersBusy}
              onChange={(e) => setFeedId(e.target.value as string)}
            >
              <MenuItem value="">Any</MenuItem>
              {feeds.map((f) => (
                <MenuItem key={f.id} value={f.id}>
                  {f.title?.trim() || f.id}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        )}
        {(kind === 'weather' || kind === 'weather_alerts') && (
          <FormControl size="small" sx={{ minWidth: 200 }}>
            <InputLabel id="loc-filter">Location</InputLabel>
            <Select
              labelId="loc-filter"
              label="Location"
              value={locationId}
              disabled={metadataFiltersBusy}
              onChange={(e) => setLocationId(e.target.value as string)}
            >
              <MenuItem value="">Any</MenuItem>
              {locations.map((l) => (
                <MenuItem key={l.id} value={l.id}>
                  {l.name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        )}
        {kind === 'tasks' && (
          <TextField
            size="small"
            label="Board key"
            value={boardKey}
            onChange={(e) => setBoardKey(e.target.value)}
            placeholder="Filter by board…"
            sx={{ minWidth: 220 }}
          />
        )}
        {integrationFilter &&
        catalogDataKindForIntegrationType(integrationFilter.integrationType) === kind ? (
          <Chip
            size="small"
            label={`Integration: ${integrationDisplayName(integrationFilter.integrationType)}`}
            onDelete={clearIntegrationFilter}
            sx={{ alignSelf: 'center' }}
          />
        ) : null}
      </Stack>

      <DisplayRefreshIndicator loading={catalogLoading} />
      {layout === 'card' && displayRows.length > 0 ? (
        <Box sx={catalogCardGridSx}>
          {displayRows.map((row, i) => (
            <DataCatalogCard
              key={catalogRowKey(kind, row, i)}
              kind={kind}
              row={row}
              display={active}
              categories={categories}
              feeds={feeds}
              integrationAccounts={integrationAccounts}
              icalFeedsById={icalFeedsById}
              canModerate={canModerate}
              canSuppress={canSuppress(kind)}
              formatDateTime={formatDateTime}
              onPatchSuppressed={(id, next) => void patchSuppressed(id, next)}
              onDelete={() => void deleteRow(row)}
              canDelete={contentDeletePath(kind, row) != null}
            />
          ))}
        </Box>
      ) : (
      <TableContainer component={Paper}>
        <Table size="small" stickyHeader>
          <TableHead>
            <TableRow>
              {kind === 'jokes' && (
                <>
                  <TableCell>Category</TableCell>
                  <TableCell>Setup</TableCell>
                  <TableCell>Punchline</TableCell>
                  <TableCell>Source</TableCell>
                  {canModerate && <TableCell width={100}>Suppressed</TableCell>}
                </>
              )}
              {kind === 'trivia' && (
                <>
                  <TableCell>Category</TableCell>
                  <TableCell>Question</TableCell>
                  <TableCell>Options</TableCell>
                  <TableCell>Source</TableCell>
                  {canModerate && <TableCell width={100}>Suppressed</TableCell>}
                </>
              )}
              {kind === 'news' && (
                <>
                  <TableCell>Image</TableCell>
                  <TableCell>Title</TableCell>
                  <TableCell>Summary</TableCell>
                  <TableCell>Source</TableCell>
                  {canModerate && <TableCell width={100}>Suppressed</TableCell>}
                </>
              )}
              {kind === 'photos' && (
                <>
                  <TableCell>Preview</TableCell>
                  <TableCell>Alt / photographer</TableCell>
                  <TableCell>Source</TableCell>
                  {canModerate && <TableCell width={100}>Suppressed</TableCell>}
                </>
              )}
              {kind === 'quoterism_quotes' && (
                <>
                  <TableCell>Author</TableCell>
                  <TableCell>Quote</TableCell>
                  <TableCell>Categories</TableCell>
                  <TableCell>Source</TableCell>
                  {canModerate && <TableCell width={100}>Suppressed</TableCell>}
                </>
              )}
              {kind === 'videos' && (
                <>
                  <TableCell>Preview</TableCell>
                  <TableCell>Alt / photographer</TableCell>
                  <TableCell>Duration</TableCell>
                  <TableCell>Source</TableCell>
                  {canModerate && <TableCell width={100}>Suppressed</TableCell>}
                </>
              )}
              {kind === 'stocks' && (
                <>
                  <TableCell>Symbol</TableCell>
                  <TableCell>Name</TableCell>
                  <TableCell>Price</TableCell>
                  <TableCell>Change %</TableCell>
                  <TableCell>Observed</TableCell>
                  <TableCell>Source</TableCell>
                </>
              )}
              {kind === 'weather' && (
                <>
                  <TableCell>Location</TableCell>
                  <TableCell>Icon</TableCell>
                  <TableCell>Temp / description</TableCell>
                  <TableCell>Observed</TableCell>
                  <TableCell>Source</TableCell>
                </>
              )}
              {kind === 'weather_alerts' && (
                <>
                  <TableCell>Location</TableCell>
                  <TableCell>Event</TableCell>
                  <TableCell>Headline</TableCell>
                  <TableCell>Severity</TableCell>
                  <TableCell>Source</TableCell>
                </>
              )}
              {kind === 'dashboard_alerts' && (
                <>
                  <TableCell>Status</TableCell>
                  <TableCell>Title</TableCell>
                  <TableCell>Body</TableCell>
                  <TableCell>Severity</TableCell>
                  <TableCell>Priority</TableCell>
                  <TableCell>Source</TableCell>
                  <TableCell>Created</TableCell>
                </>
              )}
              {kind === 'calendar_events' && (
                <>
                  <TableCell>Title</TableCell>
                  <TableCell>Start</TableCell>
                  <TableCell>End</TableCell>
                  <TableCell>All-day</TableCell>
                  <TableCell>Location</TableCell>
                  <TableCell>Category</TableCell>
                  <TableCell>Integration</TableCell>
                  <TableCell>Account / feed</TableCell>
                </>
              )}
              {kind === 'tasks' && (
                <>
                  <TableCell>Title</TableCell>
                  <TableCell>List</TableCell>
                  <TableCell>Board</TableCell>
                  <TableCell>Due</TableCell>
                  <TableCell>Done</TableCell>
                  <TableCell>Integration</TableCell>
                </>
              )}
              {canModerate ? <TableCell align="right">Actions</TableCell> : null}
            </TableRow>
          </TableHead>
          <TableBody>
            {catalogLoading ? (
              <TableRow>
                <TableCell colSpan={12}>
                  <Typography variant="body2" color="text.secondary">
                    Loading…
                  </Typography>
                </TableCell>
              </TableRow>
            ) : null}
            {!catalogLoading &&
              displayRows.map((row, index) => {
                const id = String(row.id ?? '');
                const sup = Boolean(row.suppressed);
                const rowKey = catalogRowKey(kind, row, index);
                return (
                  <TableRow key={rowKey} hover>
                    {kind === 'jokes' && (
                      <>
                        <TableCell>{categoryLabel(categories, String(row.category_id ?? ''))}</TableCell>
                        <TableCell sx={{ maxWidth: 280, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                          {String(row.setup ?? '')}
                        </TableCell>
                        <TableCell sx={{ maxWidth: 280, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                          {String(row.punchline ?? '')}
                        </TableCell>
                        <TableCell>{integrationCell(row)}</TableCell>
                        {canModerate && (
                          <TableCell>
                            <Switch
                              size="small"
                              checked={sup}
                              onChange={(_, v) => void patchSuppressed(id, v)}
                              inputProps={{ 'aria-label': `Suppress joke ${id}` }}
                            />
                          </TableCell>
                        )}
                      </>
                    )}
                    {kind === 'trivia' && (
                      <>
                        <TableCell>{categoryLabel(categories, String(row.category_id ?? ''))}</TableCell>
                        <TableCell sx={{ maxWidth: 260, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                          {String(row.question ?? '')}
                        </TableCell>
                        <TableCell sx={{ maxWidth: 320, fontSize: 12 }}>
                          {[row.option_a, row.option_b, row.option_c, row.option_d]
                            .map((o) => String(o ?? ''))
                            .filter(Boolean)
                            .join(' · ')}
                        </TableCell>
                        <TableCell>{integrationCell(row)}</TableCell>
                        {canModerate && (
                          <TableCell>
                            <Switch size="small" checked={sup} onChange={(_, v) => void patchSuppressed(id, v)} />
                          </TableCell>
                        )}
                      </>
                    )}
                    {kind === 'news' && (
                      <>
                        <TableCell>
                          <CatalogBlobMedia
                            display={active}
                            blobKey={row.image_blob_key as string | undefined}
                            variant="image"
                          />
                        </TableCell>
                        <TableCell sx={{ maxWidth: 260, wordBreak: 'break-word' }}>{String(row.title ?? '')}</TableCell>
                        <TableCell sx={{ maxWidth: 360, wordBreak: 'break-word' }}>
                          {String(row.summary ?? '')}
                        </TableCell>
                        <TableCell>{newsSourceLabel(row, feeds)}</TableCell>
                        {canModerate && (
                          <TableCell>
                            <Switch size="small" checked={sup} onChange={(_, v) => void patchSuppressed(id, v)} />
                          </TableCell>
                        )}
                      </>
                    )}
                    {kind === 'quoterism_quotes' && (
                      <>
                        <TableCell>
                          <CatalogBlobMedia
                            display={active}
                            blobKey={row.author_image_blob_key as string | undefined}
                            variant="image"
                          />
                          <Typography variant="body2" sx={{ mt: 0.5 }}>
                            {String(row.author_name ?? '—')}
                          </Typography>
                        </TableCell>
                        <TableCell sx={{ maxWidth: 360, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                          {String(row.text ?? '')}
                        </TableCell>
                        <TableCell>
                          {Array.isArray(row.category_ids)
                            ? (row.category_ids as string[])
                                .map((cid) => categoryLabel(categories, cid))
                                .join(', ')
                            : '—'}
                        </TableCell>
                        <TableCell>{integrationCell(row)}</TableCell>
                        {canModerate && (
                          <TableCell>
                            <Switch
                              size="small"
                              checked={sup}
                              onChange={(_, v) => void patchSuppressed(id, v)}
                              inputProps={{ 'aria-label': `Suppress quote ${id}` }}
                            />
                          </TableCell>
                        )}
                      </>
                    )}
                    {kind === 'photos' && (
                      <>
                        <TableCell>
                          <CatalogBlobMedia display={active} blobKey={row.media_blob_key as string | undefined} variant="image" />
                        </TableCell>
                        <TableCell sx={{ maxWidth: 280 }}>
                          <Typography variant="body2">{String(row.alt_text ?? '')}</Typography>
                          <Typography variant="caption" color="text.secondary">
                            {String(row.photographer_name ?? '')}
                          </Typography>
                        </TableCell>
                        <TableCell>{integrationCell(row)}</TableCell>
                        {canModerate && (
                          <TableCell>
                            <Switch size="small" checked={sup} onChange={(_, v) => void patchSuppressed(id, v)} />
                          </TableCell>
                        )}
                      </>
                    )}
                    {kind === 'videos' && (
                      <>
                        <TableCell>
                          <CatalogBlobMedia display={active} blobKey={row.media_blob_key as string | undefined} variant="video" />
                        </TableCell>
                        <TableCell sx={{ maxWidth: 240 }}>
                          <Typography variant="body2">{String(row.alt_text ?? '')}</Typography>
                          <Typography variant="caption" color="text.secondary">
                            {String(row.photographer_name ?? '')}
                          </Typography>
                        </TableCell>
                        <TableCell>{String(row.duration_seconds ?? '')}s</TableCell>
                        <TableCell>{integrationCell(row)}</TableCell>
                        {canModerate && (
                          <TableCell>
                            <Switch size="small" checked={sup} onChange={(_, v) => void patchSuppressed(id, v)} />
                          </TableCell>
                        )}
                      </>
                    )}
                    {kind === 'stocks' && (
                      <>
                        <TableCell>{String(row.symbol ?? '')}</TableCell>
                        <TableCell>{String(row.display_name ?? '')}</TableCell>
                        <TableCell>{row.current_price != null ? String(row.current_price) : '—'}</TableCell>
                        <TableCell>
                          {row.percent_change != null ? `${Number(row.percent_change).toFixed(2)}%` : '—'}
                        </TableCell>
                        <TableCell>
                          {row.observed_at_ms != null
                            ? formatDateTime(new Date(Number(row.observed_at_ms)))
                            : '—'}
                        </TableCell>
                        <TableCell>{integrationCell(row)}</TableCell>
                      </>
                    )}
                    {kind === 'weather' && (
                      <>
                        <TableCell>{String(row.location_name ?? row.location_id ?? '')}</TableCell>
                        <TableCell>
                          <CatalogBlobMedia
                            display={active}
                            blobKey={row.current_icon_blob_key as string | undefined}
                            variant="image"
                          />
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2">
                            {row.current_temp != null ? `${row.current_temp}° ` : ''}
                            {String(row.current_description ?? '')}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          {row.observed_at_ms != null
                            ? formatDateTime(new Date(Number(row.observed_at_ms)))
                            : '—'}
                        </TableCell>
                        <TableCell>{integrationCell(row)}</TableCell>
                      </>
                    )}
                    {kind === 'weather_alerts' && (
                      <>
                        <TableCell>{String(row.location_name ?? row.location_id ?? '')}</TableCell>
                        <TableCell>{String(row.event ?? '')}</TableCell>
                        <TableCell sx={{ maxWidth: 360, wordBreak: 'break-word' }}>
                          {String(row.headline ?? '')}
                        </TableCell>
                        <TableCell>{String(row.severity ?? '')}</TableCell>
                        <TableCell>{integrationCell(row)}</TableCell>
                      </>
                    )}
                    {kind === 'dashboard_alerts' && (
                      <>
                        <TableCell>
                          <Chip
                            size="small"
                            label={alertLifecycleLabel(alertLifecycleStatus(row))}
                            color={
                              alertLifecycleStatus(row) === 'active'
                                ? 'success'
                                : alertLifecycleStatus(row) === 'expired'
                                  ? 'default'
                                  : 'warning'
                            }
                            variant="outlined"
                          />
                        </TableCell>
                        <TableCell sx={{ maxWidth: 200, wordBreak: 'break-word' }}>
                          {String(row.title ?? '')}
                        </TableCell>
                        <TableCell sx={{ maxWidth: 360, wordBreak: 'break-word' }}>
                          {String(row.body ?? '')}
                        </TableCell>
                        <TableCell>
                          <Stack direction="row" spacing={0.5} alignItems="center">
                            {(() => {
                              const Icon = alertSeverityIconComponent(String(row.severity ?? ''));
                              return <Icon fontSize="small" color="action" />;
                            })()}
                            <Typography variant="body2">
                              {alertSeverityLabel(String(row.severity ?? ''))}
                            </Typography>
                          </Stack>
                        </TableCell>
                        <TableCell>{row.priority != null ? String(row.priority) : '—'}</TableCell>
                        <TableCell>{alertSourceLabel(String(row.source ?? ''))}</TableCell>
                        <TableCell>
                          {row.created_at_ms != null
                            ? formatDateTime(new Date(Number(row.created_at_ms)))
                            : '—'}
                        </TableCell>
                      </>
                    )}
                    {kind === 'tasks' && (
                      <>
                        <TableCell sx={{ maxWidth: 260, wordBreak: 'break-word' }}>
                          {String(row.title ?? '')}
                        </TableCell>
                        <TableCell>{String(row.list_label ?? '—')}</TableCell>
                        <TableCell>{String(row.board_key ?? '—')}</TableCell>
                        <TableCell>
                          {row.due_at_ms != null
                            ? formatDateTime(new Date(Number(row.due_at_ms)))
                            : '—'}
                        </TableCell>
                        <TableCell>{row.completed ? 'Yes' : 'No'}</TableCell>
                        <TableCell>{integrationCell(row)}</TableCell>
                      </>
                    )}
                    {kind === 'calendar_events' && (
                      <>
                        <TableCell sx={{ maxWidth: 260, wordBreak: 'break-word' }}>
                          {String(row.title ?? '')}
                        </TableCell>
                        <TableCell>
                          {calendarEventWhen(row.start_ms, Boolean(row.all_day), formatDateTime)}
                        </TableCell>
                        <TableCell>
                          {calendarEventWhen(row.end_ms, Boolean(row.all_day), formatDateTime)}
                        </TableCell>
                        <TableCell>{row.all_day ? 'Yes' : 'No'}</TableCell>
                        <TableCell sx={{ maxWidth: 200, wordBreak: 'break-word' }}>
                          {String(row.location ?? '') || '—'}
                        </TableCell>
                        <TableCell>{calendarCategoryCell(row, categories)}</TableCell>
                        <TableCell>
                          {parseCalendarEventSource(String(row.source ?? ''), {
                            integrationAccounts,
                            icalFeedsById,
                          }).integrationLabel}
                        </TableCell>
                        <TableCell sx={{ maxWidth: 200, wordBreak: 'break-word' }}>
                          {
                            parseCalendarEventSource(String(row.source ?? ''), {
                              integrationAccounts,
                              icalFeedsById,
                            }).accountOrFeedLabel
                          }
                        </TableCell>
                      </>
                    )}
                    {canModerate ? (
                      <TableCell align="right">
                        <Button
                          size="small"
                          color="error"
                          disabled={contentDeletePath(kind, row) == null}
                          onClick={() => void deleteRow(row)}
                        >
                          Delete
                        </Button>
                      </TableCell>
                    ) : null}
                  </TableRow>
                );
              })}
            {!catalogLoading && displayRows.length === 0 && (
              <TableRow>
                <TableCell colSpan={12}>
                  <Typography variant="body2" color="text.secondary">
                    No rows match the current filters.
                  </Typography>
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
      )}
      <DataViewPagination
        count={total}
        page={page}
        pageSize={rowsPerPage}
        onPageChange={setPage}
        onPageSizeChange={(size) => {
          setRowsPerPage(size);
          setPage(0);
        }}
      />
      <ConfirmDialogHost />
    </Stack>
  );
}
