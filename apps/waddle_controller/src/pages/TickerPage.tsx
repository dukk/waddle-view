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
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { CatalogPageToolbar } from '@/components/CatalogPageToolbar';
import { CatalogPageHelp } from '@/components/CatalogPageHelp';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { TickerTapesHelpContent } from '@/components/help/TickerTapesHelpContent';
import { TickerTapeIcon } from '@/icons/TickerTapeIcon';
import { completeDialogSave } from '@/util/dialogSave';
import { useConfigSchemas } from '@/hooks/useConfigSchemas';
import type { TickerTypeSchemaMeta } from '@/storage/configSchemaCache';
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

function sortById(a: TickerTapeRow, b: TickerTapeRow): number {
  return a.id.localeCompare(b.id);
}

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
            <TableCell>ID</TableCell>
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
                <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>{row.id}</TableCell>
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
  const { active } = useDisplay();
  const { loading, wrapRefresh } = useDisplayRefresh();
  const { layout, setLayout } = useListLayoutPreference('ticker-tapes');
  const [rows, setRows] = useState<TickerTapeRow[]>([]);
  const { schemas, error: schemasError } = useConfigSchemas(active);
  const [error, setError] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [editRow, setEditRow] = useState<TickerTapeRow | null>(null);

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

  const sortedRows = useMemo(() => [...rows].sort(sortById), [rows]);

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
      <CatalogPageToolbar layout={layout} onLayoutChange={setLayout}>
        <Button
          variant="contained"
          onClick={() => setAddOpen(true)}
          disabled={!schemas?.ticker_tape_types.length}
        >
          Add ticker tape
        </Button>
      </CatalogPageToolbar>

      {(error || schemasError) && (
        <Alert severity="error">{error ?? schemasError}</Alert>
      )}

      {sortedRows.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          No ticker tapes in the catalog yet.
        </Typography>
      ) : layout === 'card' ? (
        <Box sx={catalogCardGridSx}>
          {sortedRows.map((r) => (
            <TickerTapeCard
              key={r.id}
              row={r}
              tickerTypes={schemas?.ticker_tape_types ?? []}
              onEdit={() => setEditRow(r)}
              onDelete={() => void deleteTape(r.id)}
            />
          ))}
        </Box>
      ) : (
        <TickerTapeTable
          rows={sortedRows}
          tickerTypes={schemas?.ticker_tape_types ?? []}
          onEdit={setEditRow}
          onDelete={(id) => void deleteTape(id)}
        />
      )}

      {addOpen && schemas && (
        <AddTickerTapeDialog
          tickerTypes={schemas.ticker_tape_types}
          onClose={() => setAddOpen(false)}
          onSaved={async () => {
            setAddOpen(false);
            await load();
          }}
        />
      )}

      {editRow && schemas && (
        <EditTickerTapeDialog
          row={editRow}
          tickerTypes={schemas.ticker_tape_types}
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

function AddTickerTapeDialog({
  tickerTypes,
  onClose,
  onSaved,
}: {
  tickerTypes: TickerTypeSchemaMeta[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const [id, setId] = useState('');
  const [tickerType, setTickerType] = useState(tickerTypes[0]?.ticker_type ?? '');
  const [label, setLabel] = useState('');
  const [description, setDescription] = useState('');
  const [enabled, setEnabled] = useState(true);
  const [weight, setWeight] = useState(100);
  const [sort, setSort] = useState(0);
  const [configJsonText, setConfigJsonText] = useState('{}');
  const [err, setErr] = useState<string | null>(null);

  const submit = async () => {
    if (!active) return;
    setErr(null);
    const tid = id.trim();
    if (!tid) {
      setErr('Tape id is required.');
      return;
    }
    if (!tickerType) {
      setErr('Ticker type is required.');
      return;
    }
    try {
      let configJson: unknown = {};
      try {
        configJson = JSON.parse(configJsonText.trim() || '{}') as unknown;
        if (
          configJson === null ||
          typeof configJson !== 'object' ||
          Array.isArray(configJson)
        ) {
          setErr('config_json must be a JSON object.');
          return;
        }
      } catch {
        setErr('config_json is not valid JSON.');
        return;
      }
      await apiFetch(active, '/v1/ticker/tapes', {
        method: 'POST',
        body: JSON.stringify({
          id: tid,
          ticker_type: tickerType,
          label: label.trim() || undefined,
          description: description.trim(),
          enabled,
          frequency_weight: weight,
          sort_order: sort,
          config_json: configJson,
        }),
      });
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  return (
    <Dialog open fullWidth maxWidth="sm" onClose={onClose}>
      <DialogTitle>Add ticker tape</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {err && <Alert severity="error">{err}</Alert>}
          <TextField label="Tape id" value={id} onChange={(e) => setId(e.target.value)} required fullWidth />
          <FormControl fullWidth>
            <InputLabel id="tt">Ticker type</InputLabel>
            <Select
              labelId="tt"
              label="Ticker type"
              value={tickerType}
              onChange={(e) => setTickerType(String(e.target.value))}
            >
              {tickerTypes.map((m) => (
                <MenuItem key={m.ticker_type} value={m.ticker_type}>
                  {tickerTypeLabel(m.ticker_type, m)}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <TextField label="Label (optional)" value={label} onChange={(e) => setLabel(e.target.value)} fullWidth />
          <TextField
            label="Description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            fullWidth
            multiline
            minRows={2}
          />
          <Stack direction="row" alignItems="center" spacing={1}>
            <Switch checked={enabled} onChange={(_, v) => setEnabled(v)} />
            <Typography>Enabled</Typography>
          </Stack>
          <TextField
            label="Frequency weight"
            type="number"
            value={weight}
            onChange={(e) => setWeight(Number(e.target.value) || 0)}
            fullWidth
            helperText="Repeat this tape's marquee bundle this many times when building the list (0 = skip)."
          />
          <TextField
            label="Sort order"
            type="number"
            value={sort}
            onChange={(e) => setSort(Number(e.target.value) || 0)}
            fullWidth
            helperText="Lower numbers are merged into the marquee before higher numbers."
          />
          <TextField
            label={
              tickerType === 'static_text'
                ? 'config_json (JSON object, e.g. {"text":"Welcome"})'
                : tickerType === 'plugin'
                  ? 'config_json (JSON object, e.g. pluginId and fallbackText)'
                  : 'config_json (JSON object)'
            }
            value={configJsonText}
            onChange={(e) => setConfigJsonText(e.target.value)}
            fullWidth
            multiline
            minRows={3}
            inputProps={{ style: { fontFamily: 'monospace' } }}
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={() => void submit()}>
          Create
        </Button>
      </DialogActions>
    </Dialog>
  );
}

function EditTickerTapeDialog({
  row,
  tickerTypes,
  onClose,
  onSaved,
}: {
  row: TickerTapeRow;
  tickerTypes: TickerTypeSchemaMeta[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const [label, setLabel] = useState(row.label ?? '');
  const [description, setDescription] = useState(row.description ?? '');
  const [tickerType, setTickerType] = useState(row.ticker_type);
  const [enabled, setEnabled] = useState(row.enabled);
  const [weight, setWeight] = useState(row.frequency_weight);
  const [sort, setSort] = useState(row.sort_order);
  const [configJsonText, setConfigJsonText] = useState(() =>
    JSON.stringify(row.config_json ?? {}, null, 2),
  );
  const [err, setErr] = useState<string | null>(null);

  const save = async () => {
    if (!active) return;
    setErr(null);
    try {
      let configJson: unknown;
      try {
        configJson = JSON.parse(configJsonText.trim() || '{}') as unknown;
        if (
          configJson === null ||
          typeof configJson !== 'object' ||
          Array.isArray(configJson)
        ) {
          setErr('config_json must be a JSON object.');
          return;
        }
      } catch {
        setErr('config_json is not valid JSON.');
        return;
      }
      await apiFetch(active, `/v1/ticker/tapes/${encodeURIComponent(row.id)}`, {
        method: 'PATCH',
        body: JSON.stringify({
          label: label.trim(),
          description: description.trim(),
          ticker_type: tickerType,
          enabled,
          frequency_weight: weight,
          sort_order: sort,
          config_json: configJson,
        }),
      });
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>Edit {row.id}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {err && <Alert severity="error">{err}</Alert>}
          <FormControl fullWidth>
            <InputLabel id="ett">Ticker type</InputLabel>
            <Select
              labelId="ett"
              label="Ticker type"
              value={tickerType}
              onChange={(e) => setTickerType(String(e.target.value))}
            >
              {tickerTypes.map((m) => (
                <MenuItem key={m.ticker_type} value={m.ticker_type}>
                  {tickerTypeLabel(m.ticker_type, m)}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <TextField label="Label" value={label} onChange={(e) => setLabel(e.target.value)} fullWidth />
          <TextField
            label="Description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            fullWidth
            multiline
            minRows={2}
          />
          <Stack direction="row" alignItems="center" spacing={1}>
            <Switch checked={enabled} onChange={(_, v) => setEnabled(v)} />
            <Typography>Enabled</Typography>
          </Stack>
          <TextField
            label="Frequency weight"
            type="number"
            value={weight}
            onChange={(e) => setWeight(Number(e.target.value) || 0)}
            fullWidth
            helperText="Repeat this tape's marquee bundle this many times when building the list (0 = skip)."
          />
          <TextField
            label="Sort order"
            type="number"
            value={sort}
            onChange={(e) => setSort(Number(e.target.value) || 0)}
            fullWidth
            helperText="Lower numbers are merged into the marquee before higher numbers."
          />
          <TextField
            label={
              tickerType === 'static_text'
                ? 'config_json (JSON object, e.g. {"text":"Welcome"})'
                : tickerType === 'plugin'
                  ? 'config_json (JSON object, e.g. pluginId and fallbackText)'
                  : 'config_json (JSON object)'
            }
            value={configJsonText}
            onChange={(e) => setConfigJsonText(e.target.value)}
            fullWidth
            multiline
            minRows={4}
            inputProps={{ style: { fontFamily: 'monospace' } }}
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={() => void save()}>
          Save
        </Button>
      </DialogActions>
    </Dialog>
  );
}
