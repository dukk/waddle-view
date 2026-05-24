import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  Chip,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { DataViewEmptyState } from '@/components/dataView/DataViewEmptyState';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { useClientDataView } from '@/hooks/useClientDataView';
import { useConfirmDialog } from '@/hooks/useConfirmDialog';
import {
  buildColumnSortOptions,
  columnSortToolbarOptions,
  compareLocale,
  compareNumber,
  tieBreakLocale,
  type ColumnSortField,
} from '@/util/dataViewColumnSort';
import { CatalogPageHelp } from '@/components/CatalogPageHelp';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { ScreenSchedulingHelpContent } from '@/components/help/ScreenSchedulingHelpContent';
import {
  ScreenCarouselFallbackIcon,
  SlideScreenPreviewIcon,
} from '@/icons/slideScreenPreviewIcon';
import { screenTypePreviewKind } from '@/util/programTelemetry';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { CatalogDisplayTransferPanel } from '@/components/catalog/CatalogDisplayTransferPanel';
import { CatalogListWithTransferSection } from '@/components/catalog/CatalogListWithTransferSection';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { ScreenDialog, type ScreenDialogRow } from '@/components/screens/ScreenDialog';
import { parseJsonObject } from '@/util/json';
import { useConfigSchemas } from '@/hooks/useConfigSchemas';
import {
  exampleForScreenType,
  schemaForScreenType,
} from '@/storage/configSchemaCache';
import type { ContentCategoryOption } from '@/util/contentCategorySelect';
import { formatIntervalDisplay } from '@/util/durationInput';
import { screenListSchedulingSummary } from '@/util/screenListSummary';
import { screenTypeLabel, screenTypeMetaFor } from '@/util/screenTypeLabel';

type ScreenRow = ScreenDialogRow & {
  config_json_schema?: string;
  example_config_json?: string;
  data_key: string;
};

function screenSortFields(
  screenTypes: { screen_type: string; config_json_schema?: unknown }[],
  categories: ContentCategoryOption[],
): ColumnSortField<ScreenRow>[] {
  return [
    {
      id: 'name',
      label: 'Name',
      compare: (a, b) =>
        tieBreakLocale(
          compareLocale(screenRowTitle(a), screenRowTitle(b)),
          a.id,
          b.id,
        ),
    },
    {
      id: 'type',
      label: 'Type',
      compare: (a, b) =>
        tieBreakLocale(
          compareLocale(
            screenTypeLabel(a.screen_type, screenTypeMetaFor(screenTypes, a.screen_type)),
            screenTypeLabel(b.screen_type, screenTypeMetaFor(screenTypes, b.screen_type)),
          ),
          a.id,
          b.id,
        ),
    },
    {
      id: 'dwell',
      label: 'Dwell',
      compare: (a, b) =>
        tieBreakLocale(
          compareNumber(a.min_dwell_seconds, b.min_dwell_seconds) ||
            compareNumber(a.max_dwell_seconds, b.max_dwell_seconds),
          a.id,
          b.id,
        ),
    },
    {
      id: 'weight',
      label: 'Weight',
      compare: (a, b) =>
        tieBreakLocale(compareNumber(a.frequency_weight, b.frequency_weight), a.id, b.id),
    },
    {
      id: 'gap',
      label: 'Gap',
      compare: (a, b) =>
        tieBreakLocale(
          compareNumber(a.min_gap_between_shows_seconds, b.min_gap_between_shows_seconds),
          a.id,
          b.id,
        ),
    },
    {
      id: 'categories',
      label: 'Categories',
      compare: (a, b) =>
        tieBreakLocale(
          compareLocale(
            screenListSchedulingSummary(a, categories).categories,
            screenListSchedulingSummary(b, categories).categories,
          ),
          a.id,
          b.id,
        ),
    },
    {
      id: 'placements',
      label: 'Placements',
      compare: (a, b) =>
        tieBreakLocale(
          compareLocale(
            screenListSchedulingSummary(a, categories).placements,
            screenListSchedulingSummary(b, categories).placements,
          ),
          a.id,
          b.id,
        ),
    },
    {
      id: 'description',
      label: 'Description',
      compare: (a, b) =>
        tieBreakLocale(
          compareLocale(screenRowDescription(a), screenRowDescription(b)),
          a.id,
          b.id,
        ),
    },
  ];
}

function screenMatchesSearch(
  row: ScreenRow,
  q: string,
  typeLabel: string,
  categories: ContentCategoryOption[],
): boolean {
  const summary = screenListSchedulingSummary(row, categories);
  return (
    row.id.toLowerCase().includes(q) ||
    screenRowTitle(row).toLowerCase().includes(q) ||
    row.screen_type.toLowerCase().includes(q) ||
    typeLabel.toLowerCase().includes(q) ||
    screenRowDescription(row).toLowerCase().includes(q) ||
    summary.categories.toLowerCase().includes(q) ||
    summary.placements.toLowerCase().includes(q)
  );
}

function screenRowTitle(row: Pick<ScreenRow, 'id' | 'label'>): string {
  return (row.label ?? '').trim() || row.id;
}

function screenRowHasCustomTitle(row: Pick<ScreenRow, 'label'>): boolean {
  return Boolean((row.label ?? '').trim());
}

function screenRowDescription(row: Pick<ScreenRow, 'description'>): string {
  return typeof row.description === 'string' ? row.description.trim() : '';
}

function readOptionalString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

function readNumber(value: unknown, fallback = 0): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function readOptionalNumber(value: unknown): number | null {
  if (value == null) return null;
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function parseScreenRow(raw: Record<string, unknown>): ScreenRow | null {
  const id = typeof raw.id === 'string' ? raw.id.trim() : '';
  const screenType = typeof raw.screen_type === 'string' ? raw.screen_type.trim() : '';
  if (!id || !screenType) return null;

  let configJson = '{}';
  if (typeof raw.config_json === 'string') {
    configJson = raw.config_json;
  } else if (raw.config_json != null && typeof raw.config_json === 'object') {
    configJson = JSON.stringify(raw.config_json);
  }

  return {
    id,
    label: readOptionalString(raw.label) ?? readOptionalString(raw.name),
    description: readOptionalString(raw.description),
    screen_type: screenType,
    config_json: configJson,
    config_json_schema: readOptionalString(raw.config_json_schema),
    example_config_json: readOptionalString(raw.example_config_json),
    min_dwell_seconds: readNumber(raw.min_dwell_seconds, 10),
    max_dwell_seconds: readNumber(raw.max_dwell_seconds, 25),
    frequency_weight: readNumber(raw.frequency_weight, 100),
    min_gap_between_shows_seconds: readNumber(raw.min_gap_between_shows_seconds),
    min_placements_per_program: readNumber(raw.min_placements_per_program),
    max_placements_per_program: readOptionalNumber(raw.max_placements_per_program),
    data_key: readOptionalString(raw.data_key) ?? '',
  };
}

const screenCardPreviewSx = {
  borderRadius: 1,
  bgcolor: 'action.hover',
  minHeight: 100,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
} as const;

function ScreenTable({
  rows,
  screenTypes,
  categories,
  onEdit,
  onDelete,
}: {
  rows: ScreenRow[];
  screenTypes: { screen_type: string; config_json_schema?: unknown }[];
  categories: ContentCategoryOption[];
  onEdit: (row: ScreenRow) => void;
  onDelete: (id: string) => void;
}) {
  return (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Name</TableCell>
            <TableCell>Type</TableCell>
            <TableCell>Dwell (min–max)</TableCell>
            <TableCell>Weight</TableCell>
            <TableCell>Gap</TableCell>
            <TableCell>Categories</TableCell>
            <TableCell>Placements</TableCell>
            <TableCell>Description</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row) => {
            const title = screenRowTitle(row);
            const meta = screenTypeMetaFor(screenTypes, row.screen_type);
            const summary = screenListSchedulingSummary(row, categories);
            return (
              <TableRow key={row.id} hover>
                <TableCell sx={{ fontWeight: screenRowHasCustomTitle(row) ? 600 : 400 }}>{title}</TableCell>
                <TableCell>{screenTypeLabel(row.screen_type, meta)}</TableCell>
                <TableCell>
                  {formatIntervalDisplay(row.min_dwell_seconds)} –{' '}
                  {formatIntervalDisplay(row.max_dwell_seconds)}
                </TableCell>
                <TableCell>{row.frequency_weight}</TableCell>
                <TableCell>{formatIntervalDisplay(row.min_gap_between_shows_seconds)}</TableCell>
                <TableCell sx={{ maxWidth: 200, wordBreak: 'break-word' }}>{summary.categories}</TableCell>
                <TableCell>{summary.placements}</TableCell>
                <TableCell sx={{ maxWidth: 280, wordBreak: 'break-word' }}>
                  {screenRowDescription(row)}
                </TableCell>
                <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                  <Button size="small" onClick={() => onEdit(row)}>
                    Edit
                  </Button>
                  <Button size="small" color="error" onClick={() => onDelete(row.id)}>
                    Delete
                  </Button>
                </TableCell>
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

export function ScreensPage() {
  const { confirm, ConfirmDialogHost } = useConfirmDialog();
  const { active, displays } = useDisplay();
  const { hasPermission } = useAuth();
  const canWrite = hasPermission('screens.write');
  const { loading, wrapRefresh } = useDisplayRefresh();
  const { layout, setLayout } = useListLayoutPreference('screens');
  const [rows, setRows] = useState<ScreenRow[]>([]);
  const { schemas, error: schemasError } = useConfigSchemas(active);
  const [error, setError] = useState<string | null>(null);
  const [dialogMode, setDialogMode] = useState<'create' | 'edit' | null>(null);
  const [editRow, setEditRow] = useState<ScreenRow | null>(null);
  const [categories, setCategories] = useState<ContentCategoryOption[]>([]);

  const load = useCallback(async () => {
    if (!active) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const s = await apiJson<{ items: unknown[] }>(active, '/v1/screens');
        const items = (s.items ?? [])
          .map((raw) =>
            raw && typeof raw === 'object'
              ? parseScreenRow(raw as Record<string, unknown>)
              : null,
          )
          .filter((row): row is ScreenRow => row != null);
        setRows(items);
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    });
  }, [active, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (!active) {
      setCategories([]);
      return;
    }
    let cancelled = false;
    void (async () => {
      try {
        const res = await apiJson<{ items: ContentCategoryOption[] }>(
          active,
          '/v1/curator/categories',
        );
        if (!cancelled) {
          setCategories(
            (res.items ?? [])
              .filter((c) => typeof c.id === 'string' && c.id.trim())
              .map((c) => ({
                id: c.id.trim(),
                label: (c.label ?? c.id).trim() || c.id.trim(),
              })),
          );
        }
      } catch {
        if (!cancelled) setCategories([]);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [active]);

  const schemaForType = useCallback(
    (screenType: string) => schemaForScreenType(schemas, screenType),
    [schemas],
  );

  const exampleForType = useCallback(
    (screenType: string) => parseJsonObject(exampleForScreenType(schemas, screenType)),
    [schemas],
  );

  const screenTypes = schemas?.screen_types ?? [];

  const screenSortOptions = useMemo(
    () => buildColumnSortOptions(screenSortFields(screenTypes, categories)),
    [screenTypes, categories],
  );
  const screenSortToolbar = useMemo(
    () => columnSortToolbarOptions(screenSortFields(screenTypes, categories)),
    [screenTypes, categories],
  );

  const dataView = useClientDataView({
    items: rows,
    sortOptions: screenSortOptions,
    defaultSortId: 'name',
    useSortOrder: true,
    searchMatches: (row, q) => {
      const meta = screenTypeMetaFor(screenTypes, row.screen_type);
      const typeLabel = screenTypeLabel(row.screen_type, meta);
      return screenMatchesSearch(row, q, typeLabel, categories);
    },
  });

  const displayRows = dataView.paginated.items;

  const transferItems = useMemo(
    () =>
      dataView.allFilteredSorted.map((r) => ({
        id: r.id,
        label: screenRowTitle(r),
      })),
    [dataView.allFilteredSorted],
  );

  const deleteScreen = useCallback(
    async (id: string) => {
      if (!active) return;
      const ok = await confirm({
        title: 'Delete screen?',
        message: `Delete screen ${id}?`,
        confirmLabel: 'Delete',
        severity: 'error',
      });
      if (!ok) return;
      try {
        await apiFetch(active, `/v1/screens/${encodeURIComponent(id)}`, {
          method: 'DELETE',
        });
        await load();
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    },
    [active, confirm, load],
  );

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={3}>
      <DisplayRefreshIndicator loading={loading} />
      <Box>
        <Stack direction="row" alignItems="center" spacing={0.25} sx={{ mb: 0.5 }}>
          <Typography variant="h6" fontWeight={600}>
            Slideshow slide catalog
          </Typography>
          <CatalogPageHelp title="Screen scheduling">
            <ScreenSchedulingHelpContent />
          </CatalogPageHelp>
        </Stack>
        <Typography variant="body2" color="text.secondary">
          Catalog slide types in the main slideshow (RSS, weather, photos, and others). Set dwell
          time and frequency weight so the curator fills each program&apos;s time budget; the help
          icon explains how placement and recent-history deprioritization work.
        </Typography>
      </Box>
      {(error || schemasError) && (
        <Alert severity="error">{error ?? schemasError}</Alert>
      )}

      <CatalogListWithTransferSection
        toolbar={
          <DataViewToolbar
            layout={layout}
            onLayoutChange={setLayout}
            search={dataView.search}
            onSearchChange={dataView.setSearch}
            searchPlaceholder="Search screens…"
            sortOptions={screenSortToolbar}
            sortId={dataView.sortId}
            onSortChange={dataView.setSortId}
            order={dataView.order}
            onOrderChange={dataView.setOrder}
            onReload={() => void load()}
            reloadDisabled={loading}
            reloadAriaLabel="Reload screens"
          >
            <Button
              variant="contained"
              onClick={() => {
                setEditRow(null);
                setDialogMode('create');
              }}
              disabled={!screenTypes.length}
            >
              Add screen
            </Button>
          </DataViewToolbar>
        }
        list={
          <Stack spacing={2}>
            <DataViewEmptyState
              hasItems={rows.length > 0}
              hasFilteredMatches={displayRows.length > 0}
              emptyMessage="No screens in the catalog yet."
            />
            {displayRows.length > 0 && layout === 'card' ? (
            <Box sx={catalogCardGridSx}>
              {displayRows.map((r) => (
                <ScreenCard
                  key={r.id}
                  row={r}
                  screenTypes={screenTypes}
                  categories={categories}
                  onEdit={() => {
                    setEditRow(r);
                    setDialogMode('edit');
                  }}
                  onDelete={() => void deleteScreen(r.id)}
                />
              ))}
            </Box>
          ) : displayRows.length > 0 ? (
            <ScreenTable
              rows={displayRows}
              screenTypes={screenTypes}
              categories={categories}
              onEdit={(r) => {
                setEditRow(r);
                setDialogMode('edit');
              }}
              onDelete={(id) => void deleteScreen(id)}
            />
          ) : null}
            <DataViewPagination
              count={dataView.filteredTotal}
              page={dataView.paginated.page}
              pageSize={dataView.paginated.pageSize}
              onPageChange={dataView.setPage}
              onPageSizeChange={dataView.setPageSize}
            />
          </Stack>
        }
        transferPanel={
          canWrite && displays.length > 1 ? (
            <CatalogDisplayTransferPanel
              kind="screen"
              active={active}
              displays={displays}
              canWrite={canWrite}
              activeItems={transferItems}
              onTransferred={() => void load()}
            />
          ) : null
        }
      />

      {dialogMode && schemas && (
        <ScreenDialog
          open
          mode={dialogMode}
          active={active}
          initial={dialogMode === 'edit' ? editRow : null}
          existingScreenIds={rows.map((r) => r.id)}
          screenTypes={screenTypes}
          schemaForType={schemaForType}
          exampleForType={exampleForType}
          onClose={() => {
            setDialogMode(null);
            setEditRow(null);
          }}
          onSaved={async () => {
            setDialogMode(null);
            setEditRow(null);
            await load();
          }}
        />
      )}
      <ConfirmDialogHost />
    </Stack>
  );
}

function ScreenCard({
  row,
  screenTypes,
  categories,
  onEdit,
  onDelete,
}: {
  row: ScreenRow;
  screenTypes: { screen_type: string; config_json_schema?: unknown }[];
  categories: ContentCategoryOption[];
  onEdit: () => void;
  onDelete: () => void;
}) {
  const title = screenRowTitle(row);
  const meta = screenTypeMetaFor(screenTypes, row.screen_type);
  const typeLabel = screenTypeLabel(row.screen_type, meta);
  const previewKind = screenTypePreviewKind(row.screen_type);
  const description = screenRowDescription(row);
  const summary = screenListSchedulingSummary(row, categories);

  return (
    <Card
      variant="outlined"
      sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}
      aria-label={`${title} screen`}
    >
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Box sx={screenCardPreviewSx}>
            {previewKind ? (
              <SlideScreenPreviewIcon
                kind={previewKind}
                aria-hidden
                sx={{
                  fontSize: 64,
                  color: 'primary.main',
                  opacity: 0.72,
                }}
              />
            ) : (
              <ScreenCarouselFallbackIcon
                aria-hidden
                sx={{
                  fontSize: 64,
                  color: 'text.secondary',
                  opacity: 0.45,
                }}
              />
            )}
          </Box>
          <Typography variant="subtitle1" fontWeight={600} sx={{ wordBreak: 'break-word' }}>
            {title}
          </Typography>
          <Chip size="small" label={typeLabel} variant="outlined" sx={{ alignSelf: 'flex-start' }} />
          <Typography variant="caption" color="text.secondary" display="block">
            Dwell {formatIntervalDisplay(row.min_dwell_seconds)} –{' '}
            {formatIntervalDisplay(row.max_dwell_seconds)} · gap{' '}
            {formatIntervalDisplay(row.min_gap_between_shows_seconds)} · placements{' '}
            {summary.placements} · {summary.categories} · weight {row.frequency_weight}
          </Typography>
          {description ? (
            <Typography variant="body2" color="text.secondary" sx={{ wordBreak: 'break-word' }}>
              {description}
            </Typography>
          ) : null}
        </Stack>
      </CardContent>
      <CardActions sx={{ justifyContent: 'flex-end', px: 2, pb: 2 }}>
        <Button size="small" variant="outlined" onClick={onEdit}>
          Edit
        </Button>
        <Button size="small" variant="outlined" color="error" onClick={onDelete}>
          Delete
        </Button>
      </CardActions>
    </Card>
  );
}
