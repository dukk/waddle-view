import { useCallback, useEffect, useMemo, useState } from 'react';
import AddIcon from '@mui/icons-material/Add';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  Checkbox,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  FormControlLabel,
  IconButton,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
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
import { apiJson, ApiError } from '@/api/client';
import {
  CURATOR_LAYERS,
  createCuratorConfiguration,
  deleteCuratorConfiguration,
  fetchActiveCurator,
  fetchCuratorConfiguration,
  fetchCuratorStatePredicates,
  listCuratorConfigurations,
  updateCuratorConfiguration,
  type ActiveCuratorMatch,
  type ActiveCuratorResponse,
  type CuratorConfigurationDetail,
  type CuratorConfigurationSummary,
  type CuratorConfigurationWriteBody,
  type CuratorLayer,
  type CuratorScheduleRule,
  type CuratorStatePredicateMeta,
} from '@/api/curatorConfigurations';
import { DisplayThemePaletteSwatches } from '@/components/DisplayThemePaletteSwatches';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import { CuratorCategoriesSection } from '@/components/curator/CuratorCategoriesSection';
import { RejectTermsSection } from '@/components/curator/RejectTermsSection';
import {
  CURATOR_PROGRAM_DURATION,
  CURATOR_SORT_ORDER,
  CURATOR_TICKER_PIXELS_PER_SECOND,
  CURATOR_TICKER_PROGRAM_DURATION,
  VIEWPORT_RESERVE_PCT,
  curatorThemeIds,
} from '@/constants/curatorDisplaySettings';
import { useDisplayFormat } from '@/context/DisplayFormatContext';
import {
  displayThemeOptionById,
  mergeBuiltinAndCustomThemes,
} from '@/util/displayThemeOptions';
import { TickerPixelsPerSecondField } from '@/components/TickerPixelsPerSecondField';
import { completeDialogSave } from '@/util/dialogSave';
import {
  curatorMemberRefsFromLists,
  splitCuratorMemberRefs,
} from '@/util/curatorMemberRefs';
import { curatorConfigurationIdFromName } from '@/util/interestSlug';
import { formatIntervalDisplay } from '@/util/durationInput';
import { formatProgramDurationWithSeconds } from '@/util/programDurationFormat';
import { DataViewEmptyState } from '@/components/dataView/DataViewEmptyState';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useClientDataView } from '@/hooks/useClientDataView';
import { useConfirmDialog } from '@/hooks/useConfirmDialog';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import {
  buildColumnSortOptions,
  columnSortToolbarOptions,
  compareLocale,
  compareNumber,
  tieBreakLocale,
  type ColumnSortField,
} from '@/util/dataViewColumnSort';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import type { SavedDisplay } from '@/storage/displays';

type CuratorsTabId = 'configurations' | 'categories' | 'reject-terms';

const LAYER_CHIP_COLOR: Record<CuratorLayer, 'error' | 'primary' | 'secondary'> = {
  exclusive: 'error',
  base: 'primary',
  enhancement: 'secondary',
};

function layerLabel(layer: CuratorLayer): string {
  return layer.charAt(0).toUpperCase() + layer.slice(1);
}

function minutesToTimeInput(minutes: number | null): string {
  if (minutes == null || !Number.isFinite(minutes)) return '';
  const h = Math.floor(minutes / 60) % 24;
  const m = minutes % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function timeInputToMinutes(value: string): number | null {
  const t = value.trim();
  if (!t) return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(t);
  if (!m) return null;
  const h = Number.parseInt(m[1]!, 10);
  const min = Number.parseInt(m[2]!, 10);
  if (h < 0 || h > 23 || min < 0 || min > 59) return null;
  return h * 60 + min;
}

function emptyRule(): Omit<CuratorScheduleRule, 'configuration_id'> {
  return {
    id: '',
    priority: 0,
    state_predicate: null,
    days_of_week_mask: null,
    start_time_minutes: null,
    end_time_minutes: null,
    start_month: null,
    start_day: null,
    end_month: null,
    end_day: null,
    repeat_annually: true,
    year_exact: null,
    nth_week_of_month: null,
    nth_weekday: null,
  };
}

function ActivePreviewCard({ active }: { active: ActiveCuratorResponse | null }) {
  if (!active) {
    return (
      <Typography variant="body2" color="text.secondary">
        No active curator resolution loaded.
      </Typography>
    );
  }
  const rows: ActiveCuratorMatch[] = [];
  if (active.exclusive) rows.push(active.exclusive);
  else if (active.base) rows.push(active.base);
  rows.push(...active.enhancements);
  if (rows.length === 0) {
    return (
      <Typography variant="body2" color="text.secondary">
        No configuration matched at the display&apos;s current local time.
      </Typography>
    );
  }
  return (
    <Stack spacing={1}>
      {rows.map((row) => (
        <Stack key={`${row.layer}-${row.configuration_id}`} direction="row" spacing={1} alignItems="center">
          <Chip size="small" label={layerLabel(row.layer)} color={LAYER_CHIP_COLOR[row.layer]} />
          <Typography variant="body2" fontWeight={600}>
            {row.configuration_name}
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'monospace' }}>
            {row.configuration_id}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            — {row.match_reason}
          </Typography>
        </Stack>
      ))}
    </Stack>
  );
}

export function CuratorsPage() {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const canCuratorRead = hasPermission('curator.read');
  const canCuratorWrite = hasPermission('curator.write');
  const canRejectTerms = hasPermission('reject_terms.manage');
  const [tab, setTab] = useState<CuratorsTabId>('configurations');

  const visibleTabs = useMemo(() => {
    const tabs: { id: CuratorsTabId; label: string }[] = [
      { id: 'configurations', label: 'Configurations' },
    ];
    if (canCuratorRead) tabs.push({ id: 'categories', label: 'Categories' });
    if (canRejectTerms) tabs.push({ id: 'reject-terms', label: 'Rejected terms' });
    return tabs;
  }, [canCuratorRead, canRejectTerms]);

  useEffect(() => {
    if (!visibleTabs.some((t) => t.id === tab)) {
      setTab(visibleTabs[0]!.id);
    }
  }, [visibleTabs, tab]);

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={2}>
      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          Curators — {active.label}
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Layered program configurations (exclusive, base, enhancement), schedule rules, and
          catalog membership. Categories and reject terms apply across all programs.
        </Typography>
      </Box>

      <Paper sx={{ px: 2, pt: 1 }}>
        <Tabs
          value={tab}
          onChange={(_, v) => setTab(v as CuratorsTabId)}
          variant="scrollable"
          scrollButtons="auto"
          sx={{ borderBottom: 1, borderColor: 'divider' }}
        >
          {visibleTabs.map((t) => (
            <Tab key={t.id} label={t.label} value={t.id} />
          ))}
        </Tabs>
      </Paper>

      <Paper sx={{ p: 2 }}>
        {tab === 'configurations' && (
          <CuratorConfigurationsSection
            display={active}
            canRead={canCuratorRead}
            canWrite={canCuratorWrite}
          />
        )}
        {tab === 'categories' && (
          <>
            {!canCuratorRead && (
              <Alert severity="warning">
                Your adopted role does not include <strong>curator.read</strong>.
              </Alert>
            )}
            {canCuratorRead && (
              <CuratorCategoriesSection display={active} canWrite={canCuratorWrite} />
            )}
          </>
        )}
        {tab === 'reject-terms' && (
          <>
            {!canRejectTerms && (
              <Alert severity="warning">
                Your adopted role does not include <strong>reject_terms.manage</strong>.
              </Alert>
            )}
            {canRejectTerms && <RejectTermsSection display={active} />}
          </>
        )}
      </Paper>
    </Stack>
  );
}

const CURATOR_CONFIG_SORT_FIELDS: ColumnSortField<CuratorConfigurationSummary>[] = [
  {
    id: 'name',
    label: 'Name',
    compare: (a, b) => tieBreakLocale(compareLocale(a.name, b.name), a.id, b.id),
  },
  {
    id: 'layer',
    label: 'Layer',
    compare: (a, b) => tieBreakLocale(compareLocale(a.layer, b.layer), a.id, b.id),
  },
  {
    id: 'sort_order',
    label: 'Sort',
    compare: (a, b) => tieBreakLocale(compareNumber(a.sort_order, b.sort_order), a.id, b.id),
  },
  {
    id: 'program',
    label: 'Program',
    compare: (a, b) =>
      tieBreakLocale(
        compareNumber(a.program_duration_seconds, b.program_duration_seconds) ||
          compareNumber(
            a.ticker_program_duration_seconds ?? 0,
            b.ticker_program_duration_seconds ?? 0,
          ),
        a.id,
        b.id,
      ),
  },
];

const CURATOR_CONFIG_SORT_OPTIONS = buildColumnSortOptions(CURATOR_CONFIG_SORT_FIELDS);
const CURATOR_CONFIG_SORT_TOOLBAR = columnSortToolbarOptions(CURATOR_CONFIG_SORT_FIELDS);

function CuratorConfigurationsSection({
  display,
  canRead,
  canWrite,
}: {
  display: SavedDisplay;
  canRead: boolean;
  canWrite: boolean;
}) {
  const { confirm, ConfirmDialogHost } = useConfirmDialog();
  const { layout, setLayout } = useListLayoutPreference('curators');
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [error, setError] = useState<string | null>(null);
  const [rows, setRows] = useState<CuratorConfigurationSummary[]>([]);
  const [activePreview, setActivePreview] = useState<ActiveCuratorResponse | null>(null);
  const [editId, setEditId] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);

  const load = useCallback(async () => {
    if (!canRead) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const [list, active] = await Promise.all([
          listCuratorConfigurations(display),
          fetchActiveCurator(display),
        ]);
        setRows(list);
        setActivePreview(active);
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    });
  }, [canRead, display, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load]);

  const dataView = useClientDataView({
    items: rows,
    sortOptions: CURATOR_CONFIG_SORT_OPTIONS,
    defaultSortId: 'sort_order',
    useSortOrder: true,
    searchMatches: (row, q) =>
      row.name.toLowerCase().includes(q) ||
      row.id.toLowerCase().includes(q) ||
      row.layer.toLowerCase().includes(q),
  });

  const displayRows = dataView.paginated.items;

  const deleteConfig = async (id: string) => {
    const ok = await confirm({
      title: 'Delete configuration?',
      message: `Delete curator configuration "${id}"?`,
      confirmLabel: 'Delete',
      severity: 'error',
    });
    if (!ok) return;
    try {
      await deleteCuratorConfiguration(display, id);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  if (!canRead) {
    return (
      <Alert severity="warning">
        Your adopted role does not include <strong>curator.read</strong>, so curator
        configurations are not available.
      </Alert>
    );
  }

  return (
    <Stack spacing={3}>
      <DisplayRefreshIndicator loading={loading} />
      {error && <Alert severity="error">{error}</Alert>}

      <Box>
        <Typography variant="subtitle2" fontWeight={600} gutterBottom>
          Active now
        </Typography>
        <Paper variant="outlined" sx={{ p: 2 }}>
          <ActivePreviewCard active={activePreview} />
        </Paper>
      </Box>

      <Typography variant="subtitle2" fontWeight={600}>
        Configurations
      </Typography>

      <DataViewToolbar
        layout={layout}
        onLayoutChange={setLayout}
        search={dataView.search}
        onSearchChange={dataView.setSearch}
        searchPlaceholder="Search configurations…"
        sortOptions={CURATOR_CONFIG_SORT_TOOLBAR}
        sortId={dataView.sortId}
        onSortChange={dataView.setSortId}
        order={dataView.order}
        onOrderChange={dataView.setOrder}
        onReload={() => void load()}
        reloadDisabled={loading}
        reloadAriaLabel="Reload curator configurations"
      >
        {canWrite && (
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => setAddOpen(true)}>
            Add configuration
          </Button>
        )}
      </DataViewToolbar>

      <Stack spacing={2}>
        <DataViewEmptyState
          hasItems={rows.length > 0}
          hasFilteredMatches={displayRows.length > 0}
          emptyMessage="No curator configurations yet."
        />
        {displayRows.length > 0 && layout === 'card' ? (
          <Box sx={catalogCardGridSx}>
            {displayRows.map((row) => (
              <Card key={row.id} variant="outlined">
                <CardContent>
                  <Typography variant="subtitle1" fontWeight={600}>
                    {row.name}
                  </Typography>
                  <Stack direction="row" spacing={1} sx={{ mt: 1 }} flexWrap="wrap">
                    <Chip
                      size="small"
                      label={layerLabel(row.layer)}
                      color={LAYER_CHIP_COLOR[row.layer]}
                    />
                    <Chip size="small" variant="outlined" label={`Sort ${row.sort_order}`} />
                  </Stack>
                  <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                    Program {formatIntervalDisplay(row.program_duration_seconds)} / ticker{' '}
                    {formatTickerProgramDurationSummary(row.ticker_program_duration_seconds)}
                  </Typography>
                </CardContent>
                <CardActions sx={{ justifyContent: 'flex-end' }}>
                  <Button size="small" onClick={() => setEditId(row.id)}>
                    Edit
                  </Button>
                  {canWrite && (
                    <Button size="small" color="error" onClick={() => void deleteConfig(row.id)}>
                      Delete
                    </Button>
                  )}
                </CardActions>
              </Card>
            ))}
          </Box>
        ) : displayRows.length > 0 ? (
          <TableContainer component={Paper} variant="outlined">
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Name</TableCell>
                  <TableCell>Layer</TableCell>
                  <TableCell>Sort</TableCell>
                  <TableCell>Program</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {displayRows.map((row) => (
                  <TableRow key={row.id} hover>
                    <TableCell sx={{ fontWeight: 600 }}>{row.name}</TableCell>
                    <TableCell>
                      <Chip
                        size="small"
                        label={layerLabel(row.layer)}
                        color={LAYER_CHIP_COLOR[row.layer]}
                      />
                    </TableCell>
                    <TableCell>{row.sort_order}</TableCell>
                    <TableCell>
                      {formatIntervalDisplay(row.program_duration_seconds)} /{' '}
                      {formatTickerProgramDurationSummary(row.ticker_program_duration_seconds)}
                    </TableCell>
                    <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                      <Button size="small" onClick={() => setEditId(row.id)}>
                        Edit
                      </Button>
                      {canWrite && (
                        <Button size="small" color="error" onClick={() => void deleteConfig(row.id)}>
                          Delete
                        </Button>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        ) : null}
        <DataViewPagination
          count={dataView.filteredTotal}
          page={dataView.paginated.page}
          pageSize={dataView.paginated.pageSize}
          onPageChange={dataView.setPage}
          onPageSizeChange={dataView.setPageSize}
        />
      </Stack>

      {addOpen && (
        <CuratorConfigurationDialog
          display={display}
          canWrite={canWrite}
          existingConfigurationIds={rows.map((r) => r.id)}
          onClose={() => setAddOpen(false)}
          onSaved={async () => {
            setAddOpen(false);
            await load();
          }}
        />
      )}
      {editId && (
        <CuratorConfigurationDialog
          display={display}
          canWrite={canWrite}
          configurationId={editId}
          onClose={() => setEditId(null)}
          onSaved={async () => {
            setEditId(null);
            await load();
          }}
        />
      )}
      <ConfirmDialogHost />
    </Stack>
  );
}

type CatalogOption = { id: string; label: string };

type ConfigDialogTabId = 'general' | 'screens' | 'ticker' | 'schedule' | 'overlay' | 'advanced';

const DISPLAY_DEFAULT_THEME_VALUE = '';

/** Operator-facing label for catalog members (name/label only; optional id-free fallback). */
function catalogMemberDisplayLabel(
  name: string | undefined | null,
  id: string,
  options?: { unnamedLabel?: string },
): string {
  const trimmed = name?.trim();
  if (trimmed) {
    return trimmed;
  }
  return options?.unnamedLabel ?? id;
}

function tickerTapeDisplayLabel(label: string | undefined | null): string {
  return catalogMemberDisplayLabel(label, '', { unnamedLabel: 'Unnamed tape' });
}

function formatTickerProgramDurationSummary(seconds: number | null): string {
  return seconds == null ? 'display default' : formatIntervalDisplay(seconds);
}

function CuratorConfigurationDialog({
  display,
  canWrite,
  configurationId,
  existingConfigurationIds = [],
  onClose,
  onSaved,
}: {
  display: SavedDisplay;
  canWrite: boolean;
  configurationId?: string;
  existingConfigurationIds?: string[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { settings: displaySettings } = useDisplayFormat();
  const themeOptions = useMemo(
    () =>
      mergeBuiltinAndCustomThemes(
        curatorThemeIds,
        displaySettings?.display_custom_themes ?? [],
      ),
    [displaySettings?.display_custom_themes],
  );
  const isNew = configurationId == null;
  const [loading, setLoading] = useState(!isNew);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [layer, setLayer] = useState<CuratorLayer>('base');
  const [sortOrder, setSortOrder] = useState<number>(CURATOR_SORT_ORDER.default);
  const [programDuration, setProgramDuration] = useState<number>(
    CURATOR_PROGRAM_DURATION.default,
  );
  const [tickerProgramDuration, setTickerProgramDuration] = useState<number>(
    CURATOR_TICKER_PROGRAM_DURATION.default,
  );
  const [tickerPixelsPerSecond, setTickerPixelsPerSecond] = useState<number>(
    CURATOR_TICKER_PIXELS_PER_SECOND.default,
  );
  const [themeIdOverride, setThemeIdOverride] = useState<string | null>(null);
  const [useDisplayViewportReserveDefaults, setUseDisplayViewportReserveDefaults] = useState(true);
  const [useDisplayTickerDefaults, setUseDisplayTickerDefaults] = useState(true);
  const [viewportReserveTopOverride, setViewportReserveTopOverride] = useState<number>(
    VIEWPORT_RESERVE_PCT.default,
  );
  const [viewportReserveRightOverride, setViewportReserveRightOverride] = useState<number>(
    VIEWPORT_RESERVE_PCT.default,
  );
  const [viewportReserveBottomOverride, setViewportReserveBottomOverride] = useState<number>(
    VIEWPORT_RESERVE_PCT.default,
  );
  const [viewportReserveLeftOverride, setViewportReserveLeftOverride] = useState<number>(
    VIEWPORT_RESERVE_PCT.default,
  );
  const [dialogTab, setDialogTab] = useState<ConfigDialogTabId>('general');
  const [screensEnabled, setScreensEnabled] = useState(true);
  const [tickerEnabled, setTickerEnabled] = useState(true);
  const [defaultConfig, setDefaultConfig] = useState(false);
  const [parentConfigurationId, setParentConfigurationId] = useState<string | null>(null);
  const [rules, setRules] = useState<Omit<CuratorScheduleRule, 'configuration_id'>[]>([]);
  const [screenAddIds, setScreenAddIds] = useState<string[]>([]);
  const [screenRemoveIds, setScreenRemoveIds] = useState<string[]>([]);
  const [tickerAddIds, setTickerAddIds] = useState<string[]>([]);
  const [tickerRemoveIds, setTickerRemoveIds] = useState<string[]>([]);
  const [overlayAddIds, setOverlayAddIds] = useState<string[]>([]);
  const [overlayRemoveIds, setOverlayRemoveIds] = useState<string[]>([]);
  const [predicates, setPredicates] = useState<CuratorStatePredicateMeta[]>([]);
  const [screenOptions, setScreenOptions] = useState<CatalogOption[]>([]);
  const [tickerOptions, setTickerOptions] = useState<CatalogOption[]>([]);
  const [overlayOptions, setOverlayOptions] = useState<CatalogOption[]>([]);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      setErr(null);
      try {
        const [preds, screens, tickers, overlays] = await Promise.all([
          fetchCuratorStatePredicates(display),
          apiJson<{ items: { id: string; label: string }[] }>(display, '/v1/screens'),
          apiJson<{ items: { id: string; label?: string | null }[] }>(display, '/v1/ticker/tapes'),
          apiJson<{ items: { id: string; label: string }[] }>(display, '/v1/display/overlays'),
        ]);
        if (cancelled) return;
        setPredicates(preds);
        setScreenOptions(
          (screens.items ?? []).map((s) => ({
            id: s.id,
            label: catalogMemberDisplayLabel(s.label, s.id, {
              unnamedLabel: 'Unnamed screen',
            }),
          })),
        );
        setTickerOptions(
          (tickers.items ?? []).map((t) => ({
            id: t.id,
            label: tickerTapeDisplayLabel(t.label),
          })),
        );
        setOverlayOptions(
          (overlays.items ?? []).map((o) => ({
            id: o.id,
            label: catalogMemberDisplayLabel(o.label, o.id, {
              unnamedLabel: 'Unnamed overlay',
            }),
          })),
        );
        if (configurationId) {
          const detail: CuratorConfigurationDetail = await fetchCuratorConfiguration(
            display,
            configurationId,
          );
          if (cancelled) return;
          setName(detail.name);
          setLayer(detail.layer);
          setSortOrder(detail.sort_order);
          setProgramDuration(detail.program_duration_seconds);
          const useTickerDefaults =
            detail.ticker_program_duration_seconds == null &&
            detail.ticker_pixels_per_second == null;
          setUseDisplayTickerDefaults(useTickerDefaults);
          setTickerProgramDuration(
            detail.ticker_program_duration_seconds ?? CURATOR_TICKER_PROGRAM_DURATION.default,
          );
          setTickerPixelsPerSecond(
            detail.ticker_pixels_per_second ?? CURATOR_TICKER_PIXELS_PER_SECOND.default,
          );
          setThemeIdOverride(detail.theme_id_override);
          const useViewportDefaults =
            detail.viewport_reserve_top_pct_override == null &&
            detail.viewport_reserve_right_pct_override == null &&
            detail.viewport_reserve_bottom_pct_override == null &&
            detail.viewport_reserve_left_pct_override == null;
          setUseDisplayViewportReserveDefaults(useViewportDefaults);
          setViewportReserveTopOverride(
            detail.viewport_reserve_top_pct_override ?? VIEWPORT_RESERVE_PCT.default,
          );
          setViewportReserveRightOverride(
            detail.viewport_reserve_right_pct_override ?? VIEWPORT_RESERVE_PCT.default,
          );
          setViewportReserveBottomOverride(
            detail.viewport_reserve_bottom_pct_override ?? VIEWPORT_RESERVE_PCT.default,
          );
          setViewportReserveLeftOverride(
            detail.viewport_reserve_left_pct_override ?? VIEWPORT_RESERVE_PCT.default,
          );
          setScreensEnabled(detail.screens_enabled);
          setTickerEnabled(detail.ticker_enabled);
          setDefaultConfig(detail.default_config);
          setParentConfigurationId(detail.parent_configuration_id);
          setRules(
            detail.rules.map((r) => ({
              id: r.id,
              priority: r.priority,
              state_predicate: r.state_predicate,
              days_of_week_mask: r.days_of_week_mask,
              start_time_minutes: r.start_time_minutes,
              end_time_minutes: r.end_time_minutes,
              start_month: r.start_month,
              start_day: r.start_day,
              end_month: r.end_month,
              end_day: r.end_day,
              repeat_annually: r.repeat_annually,
              year_exact: r.year_exact,
              nth_week_of_month: r.nth_week_of_month,
              nth_weekday: r.nth_weekday,
            })),
          );
          const screenMembers = splitCuratorMemberRefs(detail.members.screens);
          setScreenAddIds(screenMembers.add);
          setScreenRemoveIds(screenMembers.remove);
          const tickerMembers = splitCuratorMemberRefs(detail.members.tickers);
          setTickerAddIds(tickerMembers.add);
          setTickerRemoveIds(tickerMembers.remove);
          const overlayMembers = splitCuratorMemberRefs(detail.members.overlays);
          setOverlayAddIds(overlayMembers.add);
          setOverlayRemoveIds(overlayMembers.remove);
        }
      } catch (e) {
        if (!cancelled) {
          setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [configurationId, display]);

  const showProgramFields = layer === 'base' || layer === 'exclusive';
  const isEnhancementLayer = layer === 'enhancement';

  const mergedTickerOptions = useMemo(() => {
    const byId = new Map(tickerOptions.map((o) => [o.id, o]));
    for (const id of [...tickerAddIds, ...tickerRemoveIds]) {
      if (!byId.has(id)) {
        byId.set(id, { id, label: 'Removed tape' });
      }
    }
    return [...byId.values()].sort((a, b) => a.label.localeCompare(b.label));
  }, [tickerOptions, tickerAddIds, tickerRemoveIds]);

  const mergedScreenOptions = useMemo(() => {
    const byId = new Map(screenOptions.map((o) => [o.id, o]));
    for (const id of [...screenAddIds, ...screenRemoveIds]) {
      if (!byId.has(id)) {
        byId.set(id, { id, label: 'Removed screen' });
      }
    }
    return [...byId.values()].sort((a, b) => a.label.localeCompare(b.label));
  }, [screenOptions, screenAddIds, screenRemoveIds]);

  const mergedOverlayOptions = useMemo(() => {
    const byId = new Map(overlayOptions.map((o) => [o.id, o]));
    for (const id of [...overlayAddIds, ...overlayRemoveIds]) {
      if (!byId.has(id)) {
        byId.set(id, { id, label: 'Removed overlay' });
      }
    }
    return [...byId.values()].sort((a, b) => a.label.localeCompare(b.label));
  }, [overlayOptions, overlayAddIds, overlayRemoveIds]);

  const buildBody = (configId: string): CuratorConfigurationWriteBody => ({
    name: name.trim(),
    layer,
    sort_order: sortOrder,
    program_duration_seconds: programDuration,
    ticker_program_duration_seconds:
      isEnhancementLayer || useDisplayTickerDefaults ? null : tickerProgramDuration,
    ticker_pixels_per_second:
      isEnhancementLayer || useDisplayTickerDefaults ? null : tickerPixelsPerSecond,
    theme_id_override: isEnhancementLayer ? null : themeIdOverride,
    viewport_reserve_top_pct_override:
      isEnhancementLayer || useDisplayViewportReserveDefaults ? null : viewportReserveTopOverride,
    viewport_reserve_right_pct_override:
      isEnhancementLayer || useDisplayViewportReserveDefaults ? null : viewportReserveRightOverride,
    viewport_reserve_bottom_pct_override:
      isEnhancementLayer || useDisplayViewportReserveDefaults
        ? null
        : viewportReserveBottomOverride,
    viewport_reserve_left_pct_override:
      isEnhancementLayer || useDisplayViewportReserveDefaults ? null : viewportReserveLeftOverride,
    screens_enabled: isEnhancementLayer ? true : screensEnabled,
    ticker_enabled: isEnhancementLayer ? true : tickerEnabled,
    default_config: defaultConfig,
    rules: rules.map((r) => ({
      ...r,
      id: r.id.trim(),
      configuration_id: configId,
    })),
    members: {
      screens: curatorMemberRefsFromLists({
        add: screenAddIds,
        remove: screenRemoveIds,
      }),
      tickers: curatorMemberRefsFromLists({
        add: tickerAddIds,
        remove: tickerRemoveIds,
      }),
      overlays: curatorMemberRefsFromLists({
        add: overlayAddIds,
        remove: overlayRemoveIds,
      }),
    },
  });

  const save = async () => {
    if (!canWrite) return;
    setErr(null);
    const trimmedName = name.trim();
    if (!trimmedName) {
      setErr('Name is required.');
      return;
    }
    const configId = isNew
      ? curatorConfigurationIdFromName(trimmedName, existingConfigurationIds)
      : configurationId!;
    if (isNew && !configId) {
      setErr('Name must contain at least one letter or digit.');
      return;
    }
    setSaving(true);
    try {
      if (isNew) {
        await createCuratorConfiguration(display, { id: configId, ...buildBody(configId) });
      } else {
        await updateCuratorConfiguration(display, configurationId!, buildBody(configId));
      }
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setSaving(false);
    }
  };

  const formDisabled = !canWrite || saving;

  const updateRule = (
    index: number,
    patch: Partial<Omit<CuratorScheduleRule, 'configuration_id'>>,
  ) => {
    setRules((prev) => prev.map((r, i) => (i === index ? { ...r, ...patch } : r)));
  };

  return (
    <Dialog open fullWidth maxWidth="md" onClose={onClose}>
      <DialogTitle>{isNew ? 'Add curator configuration' : `Edit ${configurationId}`}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {err && <Alert severity="error">{err}</Alert>}
          {loading ? (
            <Typography color="text.secondary">Loading…</Typography>
          ) : (
            <>
              <TextField
                label="Name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                fullWidth
                required
                helperText={
                  isNew
                    ? 'Configuration id is derived from this name (e.g. "Weekend Party" → weekend_party).'
                    : undefined
                }
              />
              <FormControl fullWidth disabled={formDisabled}>
                <InputLabel id="curator-layer">Layer</InputLabel>
                <Select
                  labelId="curator-layer"
                  label="Layer"
                  value={layer}
                  onChange={(e) => setLayer(e.target.value as CuratorLayer)}
                >
                  {CURATOR_LAYERS.map((l) => (
                    <MenuItem key={l} value={l}>
                      {layerLabel(l)}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
              <Box sx={{ borderBottom: 1, borderColor: 'divider' }}>
                <Tabs
                  value={dialogTab}
                  onChange={(_, v) => setDialogTab(v as ConfigDialogTabId)}
                  variant="scrollable"
                  scrollButtons="auto"
                >
                  <Tab label="General" value="general" />
                  <Tab label="Screens" value="screens" />
                  <Tab label="Ticker" value="ticker" />
                  <Tab label="Schedule" value="schedule" />
                  <Tab label="Overlay" value="overlay" />
                  <Tab label="Advanced" value="advanced" />
                </Tabs>
              </Box>
              {dialogTab === 'general' && (
                <Stack spacing={2}>
                  <TextField
                    label="Sort order"
                    type="number"
                    value={sortOrder}
                    onChange={(e) => setSortOrder(Number(e.target.value) || 0)}
                    fullWidth
                    disabled={formDisabled}
                    helperText="Higher values win when multiple configurations match the same schedule slot."
                  />
                  {parentConfigurationId && (
                    <TextField
                      label="Extends"
                      value={parentConfigurationId}
                      fullWidth
                      disabled
                      helperText="Shared screens and ticker tapes from the parent configuration are included at runtime."
                    />
                  )}
                  {!isEnhancementLayer && (
                  <FormControl fullWidth disabled={formDisabled}>
                    <InputLabel id="curator-theme-override-label">Theme while active</InputLabel>
                    <Select
                      labelId="curator-theme-override-label"
                      label="Theme while active"
                      value={themeIdOverride ?? DISPLAY_DEFAULT_THEME_VALUE}
                      onChange={(e) => {
                        const v = String(e.target.value);
                        setThemeIdOverride(v === DISPLAY_DEFAULT_THEME_VALUE ? null : v);
                      }}
                      renderValue={(value) => {
                        const id = String(value);
                        if (id === DISPLAY_DEFAULT_THEME_VALUE) {
                          return 'Use display default';
                        }
                        const theme = displayThemeOptionById(themeOptions, id);
                        if (!theme) {
                          return id;
                        }
                        return (
                          <Stack
                            direction="row"
                            alignItems="center"
                            spacing={1}
                            sx={{ width: '100%', pr: 0.5 }}
                          >
                            <Box
                              component="span"
                              sx={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis' }}
                            >
                              {theme.label}
                            </Box>
                            <DisplayThemePaletteSwatches groups={theme.preview} />
                          </Stack>
                        );
                      }}
                    >
                      <MenuItem value={DISPLAY_DEFAULT_THEME_VALUE}>Use display default</MenuItem>
                      {themeOptions.map((t) => (
                        <MenuItem key={t.id} value={t.id} sx={{ gap: 1 }}>
                          <Box component="span" sx={{ flex: 1 }}>
                            {t.label}
                            {t.isCustom ? ' (custom)' : ''}
                          </Box>
                          <DisplayThemePaletteSwatches groups={t.preview} />
                        </MenuItem>
                      ))}
                    </Select>
                    <Typography variant="caption" color="text.secondary" sx={{ mt: 0.75, display: 'block' }}>
                      When this configuration is the active primary curator (base or exclusive), this
                      theme replaces the display default from Display settings.
                    </Typography>
                  </FormControl>
                  )}
                  {!isEnhancementLayer && (
                    <Stack spacing={1.5}>
                      <FormControlLabel
                        control={
                          <Checkbox
                            checked={useDisplayViewportReserveDefaults}
                            onChange={(e) => setUseDisplayViewportReserveDefaults(e.target.checked)}
                            disabled={formDisabled}
                          />
                        }
                        label="Use display viewport reserve defaults"
                      />
                      {!useDisplayViewportReserveDefaults && (
                        <Stack spacing={2}>
                          <CuratorSliderField
                            label="Top reserve override (%)"
                            value={viewportReserveTopOverride}
                            onChange={setViewportReserveTopOverride}
                            min={VIEWPORT_RESERVE_PCT.min}
                            max={VIEWPORT_RESERVE_PCT.max}
                            step={VIEWPORT_RESERVE_PCT.step}
                            disabled={formDisabled}
                          />
                          <CuratorSliderField
                            label="Right reserve override (%)"
                            value={viewportReserveRightOverride}
                            onChange={setViewportReserveRightOverride}
                            min={VIEWPORT_RESERVE_PCT.min}
                            max={VIEWPORT_RESERVE_PCT.max}
                            step={VIEWPORT_RESERVE_PCT.step}
                            disabled={formDisabled}
                          />
                          <CuratorSliderField
                            label="Bottom reserve override (%)"
                            value={viewportReserveBottomOverride}
                            onChange={setViewportReserveBottomOverride}
                            min={VIEWPORT_RESERVE_PCT.min}
                            max={VIEWPORT_RESERVE_PCT.max}
                            step={VIEWPORT_RESERVE_PCT.step}
                            disabled={formDisabled}
                          />
                          <CuratorSliderField
                            label="Left reserve override (%)"
                            value={viewportReserveLeftOverride}
                            onChange={setViewportReserveLeftOverride}
                            min={VIEWPORT_RESERVE_PCT.min}
                            max={VIEWPORT_RESERVE_PCT.max}
                            step={VIEWPORT_RESERVE_PCT.step}
                            disabled={formDisabled}
                          />
                        </Stack>
                      )}
                      <Typography variant="caption" color="text.secondary">
                        When this configuration is the active primary curator, overrides the
                        viewport edge reserve from Display settings for screen and ticker layout.
                      </Typography>
                    </Stack>
                  )}
                  {isEnhancementLayer && (
                    <Typography variant="body2" color="text.secondary">
                      Theme, viewport reserve, and ticker visibility follow the active base or
                      exclusive configuration.
                    </Typography>
                  )}
                </Stack>
              )}
              {dialogTab === 'screens' && (
                <Stack spacing={2}>
                  {isEnhancementLayer ? (
                    <>
                      <Typography variant="body2" color="text.secondary">
                        Add or remove screens relative to the active base program when this
                        enhancement matches its schedule. Higher sort order wins conflicts.
                      </Typography>
                      <MemberAutocomplete
                        label="Add screens"
                        options={mergedScreenOptions}
                        value={screenAddIds}
                        onChange={setScreenAddIds}
                        disabled={formDisabled}
                      />
                      <MemberAutocomplete
                        label="Remove screens"
                        options={mergedScreenOptions}
                        value={screenRemoveIds}
                        onChange={setScreenRemoveIds}
                        disabled={formDisabled}
                      />
                    </>
                  ) : showProgramFields ? (
                    <>
                      <FormControlLabel
                        control={
                          <Checkbox
                            checked={screensEnabled}
                            onChange={(_, v) => setScreensEnabled(v)}
                            disabled={formDisabled}
                          />
                        }
                        label="Show screen program (ticker marquee can use full viewport height when off)"
                      />
                      <CuratorSliderField
                        label="Screen program duration"
                        value={programDuration}
                        onChange={setProgramDuration}
                        min={CURATOR_PROGRAM_DURATION.min}
                        max={CURATOR_PROGRAM_DURATION.max}
                        step={CURATOR_PROGRAM_DURATION.step}
                        disabled={formDisabled || !screensEnabled}
                        formatValue={formatProgramDurationWithSeconds}
                      />
                      <MemberAutocomplete
                        label="Add screens"
                        options={mergedScreenOptions}
                        value={screenAddIds}
                        onChange={setScreenAddIds}
                        disabled={formDisabled || !screensEnabled}
                      />
                      <MemberAutocomplete
                        label="Remove screens"
                        options={mergedScreenOptions}
                        value={screenRemoveIds}
                        onChange={setScreenRemoveIds}
                        disabled={formDisabled || !screensEnabled}
                      />
                    </>
                  ) : null}
                </Stack>
              )}
              {dialogTab === 'ticker' && (
                <Stack spacing={2}>
                  {isEnhancementLayer ? (
                    <>
                      <Typography variant="body2" color="text.secondary">
                        Add or remove ticker tapes relative to the active base program. Marquee
                        visibility and scroll speed follow the base or exclusive configuration.
                      </Typography>
                      <MemberAutocomplete
                        label="Add ticker tapes"
                        options={mergedTickerOptions}
                        value={tickerAddIds}
                        onChange={setTickerAddIds}
                        disabled={formDisabled}
                      />
                      <MemberAutocomplete
                        label="Remove ticker tapes"
                        options={mergedTickerOptions}
                        value={tickerRemoveIds}
                        onChange={setTickerRemoveIds}
                        disabled={formDisabled}
                      />
                    </>
                  ) : showProgramFields ? (
                    <>
                      <FormControlLabel
                        control={
                          <Checkbox
                            checked={tickerEnabled}
                            onChange={(_, v) => setTickerEnabled(v)}
                            disabled={formDisabled}
                          />
                        }
                        label="Show ticker marquee (screen program can use full viewport height when off)"
                      />
                      <FormControlLabel
                        control={
                          <Checkbox
                            checked={useDisplayTickerDefaults}
                            onChange={(e) => setUseDisplayTickerDefaults(e.target.checked)}
                            disabled={formDisabled || !tickerEnabled}
                          />
                        }
                        label="Use display ticker defaults (duration and speed)"
                      />
                      {!useDisplayTickerDefaults && (
                        <>
                          <CuratorSliderField
                            label="Ticker program duration override"
                            value={tickerProgramDuration}
                            onChange={setTickerProgramDuration}
                            min={CURATOR_TICKER_PROGRAM_DURATION.min}
                            max={CURATOR_TICKER_PROGRAM_DURATION.max}
                            step={CURATOR_TICKER_PROGRAM_DURATION.step}
                            disabled={formDisabled || !tickerEnabled}
                            formatValue={formatProgramDurationWithSeconds}
                          />
                          <TickerPixelsPerSecondField
                            value={tickerPixelsPerSecond}
                            onChange={setTickerPixelsPerSecond}
                            disabled={formDisabled || !tickerEnabled}
                          />
                        </>
                      )}
                      <Typography variant="caption" color="text.secondary">
                        Base values live in Display settings. Overrides apply when this
                        configuration is the active primary curator (base or exclusive).
                      </Typography>
                      <MemberAutocomplete
                        label="Add ticker tapes"
                        options={mergedTickerOptions}
                        value={tickerAddIds}
                        onChange={setTickerAddIds}
                        disabled={formDisabled || !tickerEnabled}
                      />
                      <MemberAutocomplete
                        label="Remove ticker tapes"
                        options={mergedTickerOptions}
                        value={tickerRemoveIds}
                        onChange={setTickerRemoveIds}
                        disabled={formDisabled || !tickerEnabled}
                      />
                    </>
                  ) : null}
                </Stack>
              )}
              {dialogTab === 'overlay' && (
                <Stack spacing={2}>
                  <Typography variant="body2" color="text.secondary">
                    Add or remove celebration overlays when this configuration is active.
                  </Typography>
                  <MemberAutocomplete
                    label="Add overlays"
                    options={mergedOverlayOptions}
                    value={overlayAddIds}
                    onChange={setOverlayAddIds}
                    disabled={formDisabled}
                  />
                  <MemberAutocomplete
                    label="Remove overlays"
                    options={mergedOverlayOptions}
                    value={overlayRemoveIds}
                    onChange={setOverlayRemoveIds}
                    disabled={formDisabled}
                  />
                </Stack>
              )}
              {dialogTab === 'advanced' && (
                <Stack spacing={2}>
                  <FormControlLabel
                    control={
                      <Checkbox
                        checked={defaultConfig}
                        onChange={(_, v) => setDefaultConfig(v)}
                        disabled={formDisabled}
                      />
                    }
                    label="Default fallback (when no schedule rule matches)"
                  />
                </Stack>
              )}
              {dialogTab === 'schedule' && (
                <>
                  <Stack direction="row" alignItems="center" justifyContent="space-between">
                    <Typography variant="subtitle2" fontWeight={600}>
                      Schedule rules
                    </Typography>
                    {canWrite && (
                      <Button
                        size="small"
                        onClick={() =>
                          setRules((prev) => [
                            ...prev,
                            { ...emptyRule(), id: `rule_${prev.length + 1}` },
                          ])
                        }
                      >
                        Add rule
                      </Button>
                    )}
                  </Stack>
                  {rules.length === 0 ? (
                    <Typography variant="body2" color="text.secondary">
                      No rules — configuration matches only when marked default fallback.
                    </Typography>
                  ) : (
                    rules.map((rule, index) => (
                  <Paper key={index} variant="outlined" sx={{ p: 2 }}>
                    <Stack spacing={1.5}>
                      <Stack direction="row" spacing={1} alignItems="center">
                        <TextField
                          label="Rule id"
                          size="small"
                          value={rule.id}
                          onChange={(e) => updateRule(index, { id: e.target.value })}
                          sx={{ flex: 1 }}
                          disabled={formDisabled}
                        />
                        <TextField
                          label="Priority"
                          size="small"
                          type="number"
                          value={rule.priority}
                          onChange={(e) =>
                            updateRule(index, { priority: Number(e.target.value) || 0 })
                          }
                          sx={{ width: 100 }}
                          disabled={formDisabled}
                        />
                        {canWrite && (
                          <IconButton
                            aria-label="Remove rule"
                            color="error"
                            onClick={() => setRules((prev) => prev.filter((_, i) => i !== index))}
                          >
                            <DeleteOutlineIcon />
                          </IconButton>
                        )}
                      </Stack>
                      <FormControl fullWidth size="small">
                        <InputLabel id={`pred-${index}`}>State predicate</InputLabel>
                        <Select
                          labelId={`pred-${index}`}
                          label="State predicate"
                          value={rule.state_predicate ?? ''}
                          onChange={(e) =>
                            updateRule(index, {
                              state_predicate: e.target.value ? String(e.target.value) : null,
                            })
                          }
                          disabled={formDisabled}
                        >
                          <MenuItem value="">
                            <em>None (calendar / time only)</em>
                          </MenuItem>
                          {predicates.map((p) => (
                            <MenuItem key={p.id} value={p.id} disabled={!p.implemented}>
                              {p.label}
                              {!p.implemented ? ' (not wired)' : ''}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
                        <TextField
                          label="Start time"
                          size="small"
                          placeholder="HH:MM"
                          value={minutesToTimeInput(rule.start_time_minutes)}
                          onChange={(e) =>
                            updateRule(index, {
                              start_time_minutes: timeInputToMinutes(e.target.value),
                            })
                          }
                          disabled={formDisabled}
                          fullWidth
                        />
                        <TextField
                          label="End time"
                          size="small"
                          placeholder="HH:MM"
                          value={minutesToTimeInput(rule.end_time_minutes)}
                          onChange={(e) =>
                            updateRule(index, {
                              end_time_minutes: timeInputToMinutes(e.target.value),
                            })
                          }
                          disabled={formDisabled}
                          fullWidth
                        />
                      </Stack>
                      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
                        <TextField
                          label="Start month"
                          size="small"
                          type="number"
                          inputProps={{ min: 1, max: 12 }}
                          value={rule.start_month ?? ''}
                          onChange={(e) =>
                            updateRule(index, {
                              start_month: e.target.value ? Number(e.target.value) : null,
                            })
                          }
                          disabled={formDisabled}
                          fullWidth
                        />
                        <TextField
                          label="Start day"
                          size="small"
                          type="number"
                          inputProps={{ min: 1, max: 31 }}
                          value={rule.start_day ?? ''}
                          onChange={(e) =>
                            updateRule(index, {
                              start_day: e.target.value ? Number(e.target.value) : null,
                            })
                          }
                          disabled={formDisabled}
                          fullWidth
                        />
                        <TextField
                          label="End month"
                          size="small"
                          type="number"
                          inputProps={{ min: 1, max: 12 }}
                          value={rule.end_month ?? ''}
                          onChange={(e) =>
                            updateRule(index, {
                              end_month: e.target.value ? Number(e.target.value) : null,
                            })
                          }
                          disabled={formDisabled}
                          fullWidth
                        />
                        <TextField
                          label="End day"
                          size="small"
                          type="number"
                          inputProps={{ min: 1, max: 31 }}
                          value={rule.end_day ?? ''}
                          onChange={(e) =>
                            updateRule(index, {
                              end_day: e.target.value ? Number(e.target.value) : null,
                            })
                          }
                          disabled={formDisabled}
                          fullWidth
                        />
                      </Stack>
                      <FormControlLabel
                        control={
                          <Checkbox
                            checked={rule.repeat_annually}
                            onChange={(_, v) => updateRule(index, { repeat_annually: v })}
                            disabled={formDisabled}
                          />
                        }
                        label="Repeat annually"
                      />
                    </Stack>
                  </Paper>
                ))
                  )}
                </>
              )}
            </>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        {canWrite && (
          <Button
            variant="contained"
            onClick={() => void save()}
            disabled={loading || saving}
          >
            {saving ? 'Saving…' : 'Save'}
          </Button>
        )}
      </DialogActions>
    </Dialog>
  );
}

function MemberAutocomplete({
  label,
  options,
  value,
  onChange,
  disabled,
}: {
  label: string;
  options: CatalogOption[];
  value: string[];
  onChange: (ids: string[]) => void;
  disabled?: boolean;
}) {
  const selected = options.filter((o) => value.includes(o.id));
  return (
    <Autocomplete
      multiple
      options={options}
      value={selected}
      onChange={(_, v) => onChange(v.map((o) => o.id))}
      getOptionLabel={(o) => o.label}
      isOptionEqualToValue={(a, b) => a.id === b.id}
      renderInput={(params) => <TextField {...params} label={label} />}
      disabled={disabled}
    />
  );
}
