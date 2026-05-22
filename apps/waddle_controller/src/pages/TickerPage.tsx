import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Paper,
  Stack,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
} from '@mui/material';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { CatalogDisplayTransferPanel } from '@/components/catalog/CatalogDisplayTransferPanel';
import { CatalogListWithTransferSection } from '@/components/catalog/CatalogListWithTransferSection';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { DataViewEmptyState } from '@/components/dataView/DataViewEmptyState';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { useClientDataView } from '@/hooks/useClientDataView';
import type { SortOption } from '@/util/clientListPipeline';
import { CatalogPageHelp } from '@/components/CatalogPageHelp';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { TickerTapesHelpContent } from '@/components/help/TickerTapesHelpContent';
import { TickerTapeIcon } from '@/icons/TickerTapeIcon';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import type { ContentCategoryOption } from '@/components/config/ContentCategorySelectField';
import { TickerConfigPanel } from '@/components/ticker/TickerConfigPanel';
import { completeDialogSave } from '@/util/dialogSave';
import { parseJsonObject } from '@/util/json';
import { useConfigSchemas } from '@/hooks/useConfigSchemas';
import {
  exampleForTickerType,
  schemaForTickerType,
  type ConfigSchemasBundle,
  type TickerTypeSchemaMeta,
} from '@/storage/configSchemaCache';
import { tickerTapeIdFromLabel } from '@/util/catalogIdFromLabel';
import { prepareRjsfSchema, validateConfigAgainstSchema } from '@/util/rjsfSchema';
import { tickerTypeLabel, tickerTypeMetaFor } from '@/util/tickerTypeLabel';

const tickerCardPreviewSx = {
  borderRadius: 1,
  bgcolor: 'action.hover',
  minHeight: 100,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
} as const;

type TickerTapeRow = {
  id: string;
  label?: string | null;
  description?: string;
  enabled: boolean;
  ticker_type: string;
  frequency_weight: number;
  sort_order: number;
  config_json?: unknown;
  config_json_schema?: unknown;
  example_config_json?: unknown;
};

const TICKER_SORT_OPTIONS: SortOption<TickerTapeRow>[] = [
  {
    id: 'label_asc',
    label: 'Name (A–Z)',
    compare: (a, b) => tickerRowTitle(a).localeCompare(tickerRowTitle(b)),
  },
  {
    id: 'label_desc',
    label: 'Name (Z–A)',
    compare: (a, b) => tickerRowTitle(b).localeCompare(tickerRowTitle(a)),
  },
  {
    id: 'sort_order',
    label: 'Sort order',
    compare: (a, b) =>
      a.sort_order - b.sort_order || tickerRowTitle(a).localeCompare(tickerRowTitle(b)),
  },
];

function trimOptionalString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function tickerRowTitle(row: Pick<TickerTapeRow, 'id' | 'label'>): string {
  return trimOptionalString(row.label) || row.id;
}

function tickerRowHasCustomLabel(row: Pick<TickerTapeRow, 'label'>): boolean {
  return trimOptionalString(row.label).length > 0;
}

function tickerRowDescription(row: Pick<TickerTapeRow, 'description'>): string {
  return trimOptionalString(row.description);
}

function readOptionalString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

function readNumber(value: unknown, fallback = 0): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function readBoolean(value: unknown, fallback = true): boolean {
  return typeof value === 'boolean' ? value : fallback;
}

function parseTickerTapeRow(raw: Record<string, unknown>): TickerTapeRow | null {
  const id = typeof raw.id === 'string' ? raw.id.trim() : '';
  const tickerType = typeof raw.ticker_type === 'string' ? raw.ticker_type.trim() : '';
  if (!id || !tickerType) return null;

  let configJson: unknown = {};
  if (typeof raw.config_json === 'string') {
    try {
      configJson = JSON.parse(raw.config_json) as unknown;
    } catch {
      configJson = {};
    }
  } else if (raw.config_json != null && typeof raw.config_json === 'object') {
    configJson = raw.config_json;
  }

  return {
    id,
    label: readOptionalString(raw.label) ?? readOptionalString(raw.name),
    description: readOptionalString(raw.description),
    enabled: readBoolean(raw.enabled, true),
    ticker_type: tickerType,
    frequency_weight: readNumber(raw.frequency_weight, 100),
    sort_order: readNumber(raw.sort_order, 0),
    config_json: configJson,
    config_json_schema: raw.config_json_schema,
    example_config_json: raw.example_config_json,
  };
}

function TickerTapeTable({
  rows,
  tickerTypes,
  onEdit,
  onDelete,
}: {
  rows: TickerTapeRow[];
  tickerTypes: TickerTypeSchemaMeta[];
  onEdit: (row: TickerTapeRow) => void;
  onDelete: (id: string) => void;
}) {
  return (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Name</TableCell>
            <TableCell>Type</TableCell>
            <TableCell>Weight</TableCell>
            <TableCell>Sort</TableCell>
            <TableCell>Enabled</TableCell>
            <TableCell>Description</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row) => {
            const title = tickerRowTitle(row);
            const description = tickerRowDescription(row);
            return (
              <TableRow key={row.id} hover>
                <TableCell sx={{ fontWeight: tickerRowHasCustomLabel(row) ? 600 : 400 }}>
                  {title}
                </TableCell>
                <TableCell>
                  {tickerTypeLabel(row.ticker_type, tickerTypeMetaFor(tickerTypes, row.ticker_type))}
                </TableCell>
                <TableCell>{row.frequency_weight}</TableCell>
                <TableCell>{row.sort_order}</TableCell>
                <TableCell>{row.enabled ? 'Yes' : 'No'}</TableCell>
                <TableCell sx={{ maxWidth: 280, wordBreak: 'break-word' }}>
                  {description}
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

export function TickerPage() {
  const { active, displays } = useDisplay();
  const { hasPermission } = useAuth();
  const canWrite = hasPermission('ticker.write');
  const { loading, wrapRefresh } = useDisplayRefresh();
  const { layout, setLayout } = useListLayoutPreference('ticker-tapes');
  const [rows, setRows] = useState<TickerTapeRow[]>([]);
  const { schemas, error: schemasError } = useConfigSchemas(active);
  const [error, setError] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [editRow, setEditRow] = useState<TickerTapeRow | null>(null);
  const [categories, setCategories] = useState<ContentCategoryOption[]>([]);

  const load = useCallback(async () => {
    if (!active) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const tapes = await apiJson<{ items: unknown[] }>(active, '/v1/ticker/tapes');
        const items = (tapes.items ?? [])
          .map((raw) =>
            raw && typeof raw === 'object'
              ? parseTickerTapeRow(raw as Record<string, unknown>)
              : null,
          )
          .filter((row): row is TickerTapeRow => row != null);
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
    void apiJson<{ items: { id: string; label: string }[] }>(active, '/v1/curator/categories')
      .then((body) => {
        if (!cancelled) {
          setCategories(
            (body.items ?? []).map((c) => ({ id: c.id, label: c.label || c.id })),
          );
        }
      })
      .catch(() => {
        if (!cancelled) setCategories([]);
      });
    return () => {
      cancelled = true;
    };
  }, [active]);

  const tickerTypes = schemas?.ticker_tape_types ?? [];

  const dataView = useClientDataView({
    items: rows,
    sortOptions: TICKER_SORT_OPTIONS,
    defaultSortId: 'label_asc',
    searchMatches: (row, q) => {
      const typeLabel = tickerTypeLabel(
        row.ticker_type,
        tickerTypeMetaFor(tickerTypes, row.ticker_type),
      );
      return (
        row.id.toLowerCase().includes(q) ||
        tickerRowTitle(row).toLowerCase().includes(q) ||
        row.ticker_type.toLowerCase().includes(q) ||
        typeLabel.toLowerCase().includes(q) ||
        tickerRowDescription(row).toLowerCase().includes(q)
      );
    },
  });

  const displayRows = dataView.paginated.items;

  const transferItems = useMemo(
    () =>
      dataView.allFilteredSorted.map((r) => ({
        id: r.id,
        label: tickerRowTitle(r),
      })),
    [dataView.allFilteredSorted],
  );

  const deleteTape = useCallback(
    async (id: string) => {
      if (!active) return;
      if (!confirm(`Delete ticker tape ${id}?`)) return;
      try {
        await apiFetch(active, `/v1/ticker/tapes/${encodeURIComponent(id)}`, {
          method: 'DELETE',
        });
        await load();
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    },
    [active, load],
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
            Bottom marquee feeds
          </Typography>
          <CatalogPageHelp title="Ticker tapes and the curator">
            <TickerTapesHelpContent />
          </CatalogPageHelp>
        </Stack>
        <Typography variant="body2" color="text.secondary">
          Configure feeds merged into the bottom marquee—clock, weather, RSS, stocks, quotes, or
          custom copy. Sort order and frequency weight control how often each tape repeats; scroll
          speed is under Display settings.
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
            searchPlaceholder="Search ticker tapes…"
            sortOptions={TICKER_SORT_OPTIONS}
            sortId={dataView.sortId}
            onSortChange={dataView.setSortId}
            onReload={() => void load()}
            reloadDisabled={loading}
            reloadAriaLabel="Reload ticker tapes"
          >
            <Button
              variant="contained"
              onClick={() => setAddOpen(true)}
              disabled={!tickerTypes.length}
            >
              Add ticker tape
            </Button>
          </DataViewToolbar>
        }
        list={
          <Stack spacing={2}>
            <DataViewEmptyState
              hasItems={rows.length > 0}
              hasFilteredMatches={displayRows.length > 0}
              emptyMessage="No ticker tapes in the catalog yet."
            />
            {displayRows.length > 0 && layout === 'card' ? (
            <Box sx={catalogCardGridSx}>
              {displayRows.map((r) => (
                <TickerTapeCard
                  key={r.id}
                  row={r}
                  tickerTypes={tickerTypes}
                  onEdit={() => setEditRow(r)}
                  onDelete={() => void deleteTape(r.id)}
                />
              ))}
            </Box>
          ) : displayRows.length > 0 ? (
            <TickerTapeTable
              rows={displayRows}
              tickerTypes={tickerTypes}
              onEdit={setEditRow}
              onDelete={(id) => void deleteTape(id)}
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
              kind="ticker"
              active={active}
              displays={displays}
              canWrite={canWrite}
              activeItems={transferItems}
              onTransferred={() => void load()}
            />
          ) : null
        }
      />

      {addOpen && schemas && active && (
        <AddTickerTapeDialog
          active={active}
          tickerTypes={schemas.ticker_tape_types}
          categories={categories}
          existingTickerIds={rows.map((r) => r.id)}
          onClose={() => setAddOpen(false)}
          onSaved={async () => {
            setAddOpen(false);
            await load();
          }}
        />
      )}

      {editRow && schemas && active && (
        <EditTickerTapeDialog
          active={active}
          row={editRow}
          tickerTypes={schemas.ticker_tape_types}
          categories={categories}
          onClose={() => setEditRow(null)}
          onSaved={async () => {
            setEditRow(null);
            await load();
          }}
        />
      )}
    </Stack>
  );
}

function TickerTapeCard({
  row,
  tickerTypes,
  onEdit,
  onDelete,
}: {
  row: TickerTapeRow;
  tickerTypes: TickerTypeSchemaMeta[];
  onEdit: () => void;
  onDelete: () => void;
}) {
  const title = tickerRowTitle(row);
  const typeLabel = tickerTypeLabel(
    row.ticker_type,
    tickerTypeMetaFor(tickerTypes, row.ticker_type),
  );
  const description = tickerRowDescription(row);

  return (
    <Card
      variant="outlined"
      sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}
      aria-label={`${title} ticker tape`}
    >
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Box sx={tickerCardPreviewSx}>
            <TickerTapeIcon
              aria-hidden
              sx={{
                fontSize: 64,
                color: 'primary.main',
                opacity: 0.72,
              }}
            />
          </Box>
          <Typography variant="subtitle1" fontWeight={600} sx={{ wordBreak: 'break-word' }}>
            {title}
          </Typography>
          <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
            <Chip size="small" label={typeLabel} variant="outlined" sx={{ alignSelf: 'flex-start' }} />
            {!row.enabled ? (
              <Chip size="small" label="Disabled" variant="outlined" color="warning" />
            ) : null}
          </Stack>
          <Typography variant="caption" color="text.secondary" display="block">
            Weight {row.frequency_weight} · sort {row.sort_order}
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

const UNSELECTED_TICKER_TYPE = '';

function tickerSchemaBundle(tickerTypes: TickerTypeSchemaMeta[]): ConfigSchemasBundle {
  return {
    screen_types: [],
    ticker_tape_types: tickerTypes,
    overlay_types: [],
    integration_types: [],
  };
}

function AddTickerTapeDialog({
  active,
  tickerTypes,
  categories,
  existingTickerIds,
  onClose,
  onSaved,
}: {
  active: NonNullable<ReturnType<typeof useDisplay>['active']>;
  tickerTypes: TickerTypeSchemaMeta[];
  categories: ContentCategoryOption[];
  existingTickerIds: string[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const bundle = useMemo(() => tickerSchemaBundle(tickerTypes), [tickerTypes]);
  const [tickerType, setTickerType] = useState(UNSELECTED_TICKER_TYPE);
  const [label, setLabel] = useState('');
  const [description, setDescription] = useState('');
  const [enabled, setEnabled] = useState(true);
  const [weight, setWeight] = useState(100);
  const [sort, setSort] = useState(0);
  const [configForm, setConfigForm] = useState<Record<string, unknown>>({});
  const [err, setErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const previewId = useMemo(
    () => tickerTapeIdFromLabel(label, existingTickerIds),
    [label, existingTickerIds],
  );

  const configSchema = useMemo(
    () =>
      tickerType ? prepareRjsfSchema(schemaForTickerType(bundle, tickerType)) : null,
    [bundle, tickerType],
  );

  const submit = async () => {
    setErr(null);
    const labelTrim = label.trim();
    if (!labelTrim) {
      setErr('Label is required.');
      return;
    }
    if (!tickerType) {
      setErr('Select a ticker type.');
      return;
    }
    const validationErrors = validateConfigAgainstSchema(configForm, configSchema);
    if (validationErrors.length > 0) {
      setErr(validationErrors[0] ?? 'Invalid configuration.');
      return;
    }
    setSaving(true);
    try {
      await apiFetch(active, '/v1/ticker/tapes', {
        method: 'POST',
        body: JSON.stringify({
          label: labelTrim,
          description: description.trim(),
          ticker_type: tickerType,
          enabled,
          frequency_weight: weight,
          sort_order: sort,
          config_json: configForm,
        }),
      });
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open fullWidth maxWidth="md" onClose={onClose}>
      <DialogTitle>Add ticker tape</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {err && <Alert severity="error">{err}</Alert>}
          <TextField
            label="Label"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            required
            fullWidth
            autoFocus
            disabled={saving}
            helperText={
              previewId
                ? `Id will be ${previewId} (derived from this label).`
                : 'Id is derived from this label (letters and numbers).'
            }
          />
          <TextField
            label="Description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            fullWidth
            multiline
            minRows={2}
            disabled={saving}
          />
          <FormControl fullWidth disabled={saving}>
            <InputLabel id="tt">Ticker type</InputLabel>
            <Select
              labelId="tt"
              label="Ticker type"
              value={tickerType}
              displayEmpty
              onChange={(e) => {
                const next = String(e.target.value);
                setTickerType(next);
                if (next) {
                  setConfigForm(parseJsonObject(exampleForTickerType(bundle, next)));
                }
              }}
            >
              <MenuItem value={UNSELECTED_TICKER_TYPE} disabled>
                Select ticker type
              </MenuItem>
              {tickerTypes.map((m) => (
                <MenuItem key={m.ticker_type} value={m.ticker_type}>
                  {tickerTypeLabel(m.ticker_type, m)}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          {tickerType ? (
            <>
              <Stack direction="row" alignItems="center" spacing={1}>
                <Switch checked={enabled} onChange={(_, v) => setEnabled(v)} disabled={saving} />
                <Typography>Enabled</Typography>
              </Stack>
              <CuratorSliderField
                label="Frequency weight"
                value={weight}
                onChange={setWeight}
                min={0}
                max={500}
                step={5}
                disabled={saving}
              />
              <Typography variant="caption" color="text.secondary" sx={{ mt: -1 }}>
                Repeat this tape&apos;s marquee bundle this many times when building the list (0 =
                skip).
              </Typography>
              <CuratorSliderField
                label="Sort order"
                value={sort}
                onChange={setSort}
                min={0}
                max={100}
                step={1}
                disabled={saving}
              />
              <Typography variant="caption" color="text.secondary" sx={{ mt: -1 }}>
                Lower numbers are merged into the marquee before higher numbers.
              </Typography>
              <TickerConfigPanel
                display={active}
                tickerType={tickerType}
                schema={configSchema}
                formData={configForm}
                onChange={setConfigForm}
                disabled={saving}
                categories={categories}
              />
            </>
          ) : null}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={() => void submit()} disabled={saving}>
          {saving ? 'Creating…' : 'Create'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}

function EditTickerTapeDialog({
  active,
  row,
  tickerTypes,
  categories,
  onClose,
  onSaved,
}: {
  active: NonNullable<ReturnType<typeof useDisplay>['active']>;
  row: TickerTapeRow;
  tickerTypes: TickerTypeSchemaMeta[];
  categories: ContentCategoryOption[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const bundle = useMemo(() => tickerSchemaBundle(tickerTypes), [tickerTypes]);
  const [label, setLabel] = useState(row.label ?? '');
  const [description, setDescription] = useState(row.description ?? '');
  const [tickerType] = useState(row.ticker_type);
  const [enabled, setEnabled] = useState(row.enabled);
  const [weight, setWeight] = useState(row.frequency_weight);
  const [sort, setSort] = useState(row.sort_order);
  const [configForm, setConfigForm] = useState<Record<string, unknown>>(() =>
    parseJsonObject(row.config_json),
  );
  const [err, setErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const configSchema = useMemo(
    () => prepareRjsfSchema(schemaForTickerType(bundle, tickerType)),
    [bundle, tickerType],
  );

  const dialogTitle = `Edit ${tickerRowTitle(row)}`;

  const save = async () => {
    setErr(null);
    const labelTrim = label.trim();
    if (!labelTrim) {
      setErr('Label is required.');
      return;
    }
    const validationErrors = validateConfigAgainstSchema(configForm, configSchema);
    if (validationErrors.length > 0) {
      setErr(validationErrors[0] ?? 'Invalid configuration.');
      return;
    }
    setSaving(true);
    try {
      await apiFetch(active, `/v1/ticker/tapes/${encodeURIComponent(row.id)}`, {
        method: 'PATCH',
        body: JSON.stringify({
          label: labelTrim,
          description: description.trim(),
          enabled,
          frequency_weight: weight,
          sort_order: sort,
          config_json: configForm,
        }),
      });
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="md">
      <DialogTitle>{dialogTitle}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {err && <Alert severity="error">{err}</Alert>}
          <TextField
            label="Label"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            required
            fullWidth
            disabled={saving}
          />
          <TextField
            label="Description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            fullWidth
            multiline
            minRows={2}
            disabled={saving}
          />
          <FormControl fullWidth disabled>
            <InputLabel id="ett">Ticker type</InputLabel>
            <Select labelId="ett" label="Ticker type" value={tickerType}>
              {tickerTypes.map((m) => (
                <MenuItem key={m.ticker_type} value={m.ticker_type}>
                  {tickerTypeLabel(m.ticker_type, m)}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <Typography variant="caption" color="text.secondary">
            Ticker type cannot be changed after create. Delete and add a new tape to switch types.
          </Typography>
          <Stack direction="row" alignItems="center" spacing={1}>
            <Switch checked={enabled} onChange={(_, v) => setEnabled(v)} disabled={saving} />
            <Typography>Enabled</Typography>
          </Stack>
          <CuratorSliderField
            label="Frequency weight"
            value={weight}
            onChange={setWeight}
            min={0}
            max={500}
            step={5}
            disabled={saving}
          />
          <CuratorSliderField
            label="Sort order"
            value={sort}
            onChange={setSort}
            min={0}
            max={100}
            step={1}
            disabled={saving}
          />
          <TickerConfigPanel
            display={active}
            tickerType={tickerType}
            schema={configSchema}
            formData={configForm}
            onChange={setConfigForm}
            disabled={saving}
            categories={categories}
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={() => void save()} disabled={saving}>
          {saving ? 'Saving…' : 'Save'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
