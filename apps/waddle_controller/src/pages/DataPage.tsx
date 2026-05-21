import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import {
  Alert,
  Box,
  Button,
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
import { apiFetch, apiJson, ApiError, fetchBlobObjectUrl } from '@/api/client';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { sortByOption, type SortOption } from '@/util/clientListPipeline';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import type { SavedDisplay } from '@/storage/displays';
import { integrationDisplayName } from '@/util/integrationDisplayName';

type DataKind =
  | 'calendar_events'
  | 'jokes'
  | 'trivia'
  | 'news'
  | 'photos'
  | 'videos'
  | 'stocks'
  | 'weather'
  | 'weather_alerts'
  | 'dashboard_alerts';

type Paginated<T> = { items: T[]; total: number; limit?: number; offset?: number };

/** Tabs in alphabetical order by label. */
const DATA_TABS: { kind: DataKind; label: string }[] = [
  { kind: 'dashboard_alerts', label: 'Alerts' },
  { kind: 'calendar_events', label: 'Calendar' },
  { kind: 'jokes', label: 'Jokes' },
  { kind: 'news', label: 'News' },
  { kind: 'photos', label: 'Photos' },
  { kind: 'stocks', label: 'Stocks' },
  { kind: 'trivia', label: 'Trivia' },
  { kind: 'videos', label: 'Videos' },
  { kind: 'weather', label: 'Weather' },
  { kind: 'weather_alerts', label: 'Weather alerts' },
];

const COLUMN_FILTER_FIELDS: Record<DataKind, readonly { param: string; label: string }[]> = {
  calendar_events: [
    { param: 'title', label: 'Title' },
    { param: 'location', label: 'Location' },
    { param: 'description', label: 'Description' },
    { param: 'source', label: 'Source' },
  ],
  jokes: [
    { param: 'setup', label: 'Setup' },
    { param: 'punchline', label: 'Punchline' },
  ],
  trivia: [
    { param: 'question', label: 'Question' },
    { param: 'option_a', label: 'Option A' },
    { param: 'option_b', label: 'Option B' },
    { param: 'option_c', label: 'Option C' },
    { param: 'option_d', label: 'Option D' },
    { param: 'integration_type', label: 'Integration' },
  ],
  news: [
    { param: 'title', label: 'Title' },
    { param: 'summary', label: 'Summary' },
    { param: 'link', label: 'Link' },
    { param: 'guid', label: 'Guid' },
  ],
  photos: [
    { param: 'alt_text', label: 'Alt text' },
    { param: 'photographer_name', label: 'Photographer' },
    { param: 'data_provider', label: 'Provider id' },
  ],
  videos: [
    { param: 'alt_text', label: 'Alt text' },
    { param: 'photographer_name', label: 'Photographer' },
    { param: 'data_provider', label: 'Provider id' },
  ],
  stocks: [
    { param: 'symbol', label: 'Symbol' },
    { param: 'display_name', label: 'Name' },
  ],
  weather: [
    { param: 'description', label: 'Description' },
    { param: 'location_name', label: 'Location name' },
  ],
  weather_alerts: [
    { param: 'event', label: 'Event' },
    { param: 'headline', label: 'Headline' },
    { param: 'severity', label: 'Severity' },
    { param: 'excerpt', label: 'Excerpt' },
    { param: 'location_name', label: 'Location name' },
  ],
  dashboard_alerts: [
    { param: 'title', label: 'Title' },
    { param: 'body', label: 'Body' },
    { param: 'source', label: 'Source' },
    { param: 'severity', label: 'Severity' },
  ],
};

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
  }
}

function canSuppress(kind: DataKind): boolean {
  return kind === 'jokes' || kind === 'trivia' || kind === 'news' || kind === 'photos' || kind === 'videos';
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
    case 'calendar_events': {
      const id = String(row.id ?? '').trim();
      if (!id) return null;
      if (kind === 'jokes') return `/v1/content/jokes/${encodeURIComponent(id)}`;
      if (kind === 'trivia') return `/v1/content/trivia/${encodeURIComponent(id)}`;
      if (kind === 'news') return `/v1/content/rss-articles/${encodeURIComponent(id)}`;
      if (kind === 'photos') return `/v1/content/photos/${encodeURIComponent(id)}`;
      if (kind === 'videos') return `/v1/content/videos/${encodeURIComponent(id)}`;
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
  }
}

function deleteRowSummary(kind: DataKind, row: Record<string, unknown>): string {
  switch (kind) {
    case 'jokes':
      return String(row.setup ?? row.id ?? 'joke');
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

function BlobMedia({
  display,
  blobKey,
  variant,
}: {
  display: SavedDisplay;
  blobKey: string | null | undefined;
  variant: 'image' | 'video';
}) {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    if (!blobKey?.trim()) {
      setUrl(null);
      return;
    }
    let revoked: string | null = null;
    let cancelled = false;
    void (async () => {
      const u = await fetchBlobObjectUrl(display, blobKey.trim());
      if (cancelled) {
        if (u) URL.revokeObjectURL(u);
        return;
      }
      revoked = u;
      setUrl(u);
    })();
    return () => {
      cancelled = true;
      if (revoked) URL.revokeObjectURL(revoked);
    };
  }, [display, blobKey]);

  if (!url) {
    return (
      <Typography variant="caption" color="text.secondary">
        {blobKey ? '…' : '—'}
      </Typography>
    );
  }
  if (variant === 'video') {
    return (
      <video
        src={url}
        controls
        muted
        playsInline
        style={{ maxWidth: 280, maxHeight: 160, borderRadius: 4, background: '#000' }}
      />
    );
  }
  return (
    <Box
      component="img"
      src={url}
      alt=""
      sx={{ maxWidth: 200, maxHeight: 120, objectFit: 'cover', borderRadius: 1, display: 'block' }}
    />
  );
}

const DATA_ROW_SORT: SortOption<Record<string, unknown>>[] = [
  { id: 'newest', label: 'Newest on page', compare: (a, b) => rowSortMs(b) - rowSortMs(a) },
  { id: 'oldest', label: 'Oldest on page', compare: (a, b) => rowSortMs(a) - rowSortMs(b) },
];

function rowSortMs(row: Record<string, unknown>): number {
  for (const key of ['created_at_ms', 'published_at', 'fetched_at_ms', 'observed_at_ms', 'start_ms', 'effective_at']) {
    const v = row[key];
    if (typeof v === 'number' && Number.isFinite(v)) return v;
  }
  return 0;
}

function rowMatchesToolbarSearch(row: Record<string, unknown>, q: string): boolean {
  for (const value of Object.values(row)) {
    if (value == null) continue;
    if (typeof value === 'string' && value.toLowerCase().includes(q)) return true;
    if (typeof value === 'number' && String(value).includes(q)) return true;
  }
  return false;
}

function dataRowSummary(row: Record<string, unknown>, kind: DataKind): string {
  const pick = (key: string) => {
    const v = row[key];
    return typeof v === 'string' && v.trim() ? v.trim() : null;
  };
  switch (kind) {
    case 'calendar_events':
      return pick('title') ?? pick('location') ?? String(row.id ?? '');
    case 'jokes':
      return pick('setup') ?? String(row.id ?? '');
    case 'trivia':
      return pick('question') ?? String(row.id ?? '');
    case 'news':
      return pick('title') ?? String(row.id ?? '');
    case 'photos':
    case 'videos':
      return pick('alt_text') ?? String(row.id ?? '');
    case 'stocks':
      return pick('symbol') ?? pick('display_name') ?? String(row.id ?? '');
    case 'weather':
      return pick('location_name') ?? pick('description') ?? String(row.id ?? '');
    case 'weather_alerts':
      return pick('event') ?? pick('headline') ?? String(row.id ?? '');
    case 'dashboard_alerts':
      return pick('title') ?? String(row.id ?? '');
    default:
      return String(row.id ?? '');
  }
}

export function DataPage() {
  const { active } = useDisplay();
  const { formatDateTime } = useDisplayFormat();
  const { hasPermission } = useAuth();
  const { layout, setLayout } = useListLayoutPreference('data');
  const canModerate = hasPermission('content.moderate');
  const canBrowseData = canModerate || hasPermission('content.catalog_read');

  const [kind, setKind] = useState<DataKind>('jokes');
  const [toolbarSearch, setToolbarSearch] = useState('');
  const [dataSortId, setDataSortId] = useState('newest');
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(() => defaultRowsForKind('jokes'));
  const [columnFilterDrafts, setColumnFilterDrafts] = useState<Partial<Record<DataKind, Record<string, string>>>>({});
  const [columnFilters, setColumnFilters] = useState<Partial<Record<DataKind, Record<string, string>>>>({});
  const [suppressed, setSuppressed] = useState<'all' | 'true' | 'false'>('all');
  const [categoryId, setCategoryId] = useState('');
  const [feedId, setFeedId] = useState('');
  const [locationId, setLocationId] = useState('');

  const [rows, setRows] = useState<Record<string, unknown>[]>([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const { loading: metadataLoading, wrapRefresh: wrapMetadataRefresh } = useDisplayRefresh();
  const { loading: catalogLoading, wrapRefresh: wrapCatalogRefresh } = useDisplayRefresh();

  const [categories, setCategories] = useState<{ id: string; label: string }[]>([]);
  const [feeds, setFeeds] = useState<{ id: string; title: string | null; url: string }[]>([]);
  const [locations, setLocations] = useState<{ id: string; name: string }[]>([]);

  const draftForKind = columnFilterDrafts[kind] ?? {};
  const draftJson = JSON.stringify(draftForKind);

  useEffect(() => {
    setPage(0);
    setRowsPerPage(defaultRowsForKind(kind));
    setToolbarSearch('');
    setDataSortId('newest');
  }, [kind]);

  /** Cancels stale catalog fetches so a slow tab (e.g. weather) cannot overwrite rows after switching kind. */
  const catalogFetchAbortRef = useRef<AbortController | null>(null);
  /** Monotonic generation: late responses (or non-aborted fetches) cannot apply after a newer load started. */
  const catalogLoadGenerationRef = useRef(0);

  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      try {
        const parsed = JSON.parse(draftJson) as Record<string, string>;
        setColumnFilters((prev) => ({ ...prev, [kind]: parsed }));
      } catch {
        setColumnFilters((prev) => ({ ...prev, [kind]: {} }));
      }
    }, 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [draftJson, kind]);

  useEffect(() => {
    setPage(0);
  }, [suppressed, categoryId, feedId, locationId, columnFilters, rowsPerPage, kind]);

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
      } catch {
        /* optional metadata */
      }
    });
  }, [active, canBrowseData, wrapMetadataRefresh]);

  useEffect(() => {
    void loadMetadata();
  }, [loadMetadata]);

  const offset = page * rowsPerPage;

  const querySuffix = useMemo(() => {
    const p = new URLSearchParams();
    p.set('limit', String(rowsPerPage));
    p.set('offset', String(offset));
    const applied = columnFilters[kind] ?? {};
    for (const [key, value] of Object.entries(applied)) {
      const t = value.trim();
      if (t) p.set(key, t);
    }
    if (canModerate && canSuppress(kind) && suppressed !== 'all') p.set('suppressed', suppressed);
    if (
      categoryId &&
      (kind === 'calendar_events' ||
        kind === 'jokes' ||
        kind === 'trivia' ||
        kind === 'photos' ||
        kind === 'videos')
    ) {
      p.set('category', categoryId);
    }
    if (kind === 'news' && feedId) p.set('feed_id', feedId);
    if ((kind === 'weather' || kind === 'weather_alerts') && locationId) {
      p.set('location_id', locationId);
    }
    const s = p.toString();
    return s ? `?${s}` : '';
  }, [offset, columnFilters, suppressed, categoryId, feedId, locationId, kind, rowsPerPage, canModerate]);

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
      if (!window.confirm(`Permanently delete “${summary}”? This cannot be undone.`)) return;
      setError(null);
      try {
        await apiFetch(active, path, { method: 'DELETE' });
        await loadCatalog();
      } catch (e) {
        const msg = e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
        setError(msg);
      }
    },
    [active, canModerate, kind, loadCatalog],
  );

  const setFilterField = (param: string, value: string) => {
    setColumnFilterDrafts((prev) => ({
      ...prev,
      [kind]: { ...(prev[kind] ?? {}), [param]: value },
    }));
  };

  const filterFields = COLUMN_FILTER_FIELDS[kind];

  const displayRows = useMemo(() => {
    const q = toolbarSearch.trim().toLowerCase();
    let list = rows;
    if (q) {
      list = rows.filter((row) => rowMatchesToolbarSearch(row, q));
    }
    const sortOption = DATA_ROW_SORT.find((o) => o.id === dataSortId) ?? DATA_ROW_SORT[0];
    return sortByOption(list, sortOption);
  }, [rows, toolbarSearch, dataSortId]);

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
    metadataLoading &&
    (kind === 'calendar_events' ||
      kind === 'jokes' ||
      kind === 'trivia' ||
      kind === 'photos' ||
      kind === 'videos' ||
      kind === 'news' ||
      kind === 'weather' ||
      kind === 'weather_alerts');

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
          onChange={(_, v) => setKind(v as DataKind)}
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
        sortOptions={DATA_ROW_SORT}
        sortId={dataSortId}
        onSortChange={setDataSortId}
        onReload={() => void loadCatalog()}
        reloadDisabled={catalogLoading}
        reloadAriaLabel="Reload catalog data"
      />

      <Paper sx={{ p: 2 }}>
        <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1 }}>
          Column filters (substring match; multiple fields combine with AND)
        </Typography>
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ gap: 1 }}>
          {filterFields.map((f) => (
            <TextField
              key={f.param}
              label={f.label}
              size="small"
              value={draftForKind[f.param] ?? ''}
              onChange={(e) => setFilterField(f.param, e.target.value)}
              sx={{ minWidth: 140, flex: '1 1 160px' }}
            />
          ))}
        </Stack>
      </Paper>

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
        {(kind === 'calendar_events' ||
          kind === 'jokes' ||
          kind === 'trivia' ||
          kind === 'photos' ||
          kind === 'videos') && (
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
              {categories.map((c) => (
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
      </Stack>

      <DisplayRefreshIndicator loading={catalogLoading} />
      {layout === 'card' && displayRows.length > 0 ? (
        <Box sx={catalogCardGridSx}>
          {displayRows.map((row, i) => (
            <Paper key={String(row.id ?? i)} variant="outlined" sx={{ p: 2 }}>
              <Typography variant="subtitle2" fontWeight={600} gutterBottom>
                {dataRowSummary(row, kind)}
              </Typography>
              <Typography variant="caption" color="text.secondary" display="block">
                {String(row.id ?? '')}
              </Typography>
              {canModerate ? (
                <Button
                  size="small"
                  color="error"
                  sx={{ mt: 1 }}
                  disabled={contentDeletePath(kind, row) == null}
                  onClick={() => void deleteRow(row)}
                >
                  Delete
                </Button>
              ) : null}
            </Paper>
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
                  <TableCell>Integration</TableCell>
                  {canModerate && <TableCell width={100}>Suppressed</TableCell>}
                </>
              )}
              {kind === 'trivia' && (
                <>
                  <TableCell>Category</TableCell>
                  <TableCell>Question</TableCell>
                  <TableCell>Options</TableCell>
                  <TableCell>Integration</TableCell>
                  {canModerate && <TableCell width={100}>Suppressed</TableCell>}
                </>
              )}
              {kind === 'news' && (
                <>
                  <TableCell>Image</TableCell>
                  <TableCell>Title</TableCell>
                  <TableCell>Summary</TableCell>
                  <TableCell>Integration</TableCell>
                  {canModerate && <TableCell width={100}>Suppressed</TableCell>}
                </>
              )}
              {kind === 'photos' && (
                <>
                  <TableCell>Preview</TableCell>
                  <TableCell>Alt / photographer</TableCell>
                  <TableCell>Integration</TableCell>
                  {canModerate && <TableCell width={100}>Suppressed</TableCell>}
                </>
              )}
              {kind === 'videos' && (
                <>
                  <TableCell>Preview</TableCell>
                  <TableCell>Alt / photographer</TableCell>
                  <TableCell>Duration</TableCell>
                  <TableCell>Integration</TableCell>
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
                  <TableCell>Integration</TableCell>
                </>
              )}
              {kind === 'weather' && (
                <>
                  <TableCell>Location</TableCell>
                  <TableCell>Icon</TableCell>
                  <TableCell>Temp / description</TableCell>
                  <TableCell>Observed</TableCell>
                  <TableCell>Integration</TableCell>
                </>
              )}
              {kind === 'weather_alerts' && (
                <>
                  <TableCell>Location</TableCell>
                  <TableCell>Event</TableCell>
                  <TableCell>Headline</TableCell>
                  <TableCell>Severity</TableCell>
                  <TableCell>Integration</TableCell>
                </>
              )}
              {kind === 'dashboard_alerts' && (
                <>
                  <TableCell>Title</TableCell>
                  <TableCell>Body</TableCell>
                  <TableCell>Severity</TableCell>
                  <TableCell>Priority</TableCell>
                  <TableCell>Source</TableCell>
                  <TableCell>Created</TableCell>
                  <TableCell>Integration</TableCell>
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
                  <TableCell>Source</TableCell>
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
                          <BlobMedia display={active} blobKey={row.image_blob_key as string | undefined} variant="image" />
                        </TableCell>
                        <TableCell sx={{ maxWidth: 260, wordBreak: 'break-word' }}>{String(row.title ?? '')}</TableCell>
                        <TableCell sx={{ maxWidth: 360, wordBreak: 'break-word' }}>
                          {String(row.summary ?? '')}
                        </TableCell>
                        <TableCell>{integrationCell(row)}</TableCell>
                        {canModerate && (
                          <TableCell>
                            <Switch size="small" checked={sup} onChange={(_, v) => void patchSuppressed(id, v)} />
                          </TableCell>
                        )}
                      </>
                    )}
                    {kind === 'photos' && (
                      <>
                        <TableCell>
                          <BlobMedia display={active} blobKey={row.media_blob_key as string | undefined} variant="image" />
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
                          <BlobMedia display={active} blobKey={row.media_blob_key as string | undefined} variant="video" />
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
                          <BlobMedia
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
                        <TableCell sx={{ maxWidth: 200, wordBreak: 'break-word' }}>
                          {String(row.title ?? '')}
                        </TableCell>
                        <TableCell sx={{ maxWidth: 360, wordBreak: 'break-word' }}>
                          {String(row.body ?? '')}
                        </TableCell>
                        <TableCell>{String(row.severity ?? '')}</TableCell>
                        <TableCell>{row.priority != null ? String(row.priority) : '—'}</TableCell>
                        <TableCell>{String(row.source ?? '')}</TableCell>
                        <TableCell>
                          {row.created_at_ms != null
                            ? formatDateTime(new Date(Number(row.created_at_ms)))
                            : '—'}
                        </TableCell>
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
                        <TableCell>{integrationCell(row)}</TableCell>
                        <TableCell
                          sx={{ maxWidth: 180, wordBreak: 'break-word', fontSize: 12 }}
                          title={String(row.source ?? '')}
                        >
                          {String(row.source ?? '') || '—'}
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
    </Stack>
  );
}
