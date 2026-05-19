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
import { completeDialogSave } from '@/util/dialogSave';
import { useConfigSchemas } from '@/hooks/useConfigSchemas';
import type { TickerTypeSchemaMeta } from '@/storage/configSchemaCache';

type TickerTapeRow = {
  id: string;
  label?: string | null;
  description?: string;
  enabled: boolean;
  ticker_type: string;
  frequency_weight: number;
  sort_order: number;
  config_key: string | null;
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

function tickerTypeLabel(tickerType: string | null | undefined): string {
  const normalized = trimOptionalString(tickerType);
  return normalized ? normalized.replace(/_/g, ' ') : 'unknown';
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

function tickerRowConfigKey(row: Pick<TickerTapeRow, 'config_key'>): string {
  return trimOptionalString(row.config_key);
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

  const configKey = readOptionalString(raw.config_key)?.trim();

  return {
    id,
    label: readOptionalString(raw.label) ?? readOptionalString(raw.name),
    description: readOptionalString(raw.description),
    enabled: readBoolean(raw.enabled, true),
    ticker_type: tickerType,
    frequency_weight: readNumber(raw.frequency_weight, 100),
    sort_order: readNumber(raw.sort_order, 0),
    config_key: configKey ? configKey : null,
    config_json: configJson,
    config_json_schema: raw.config_json_schema,
    example_config_json: raw.example_config_json,
  };
}

function TickerTapeTable({
  rows,
  onEdit,
  onDelete,
}: {
  rows: TickerTapeRow[];
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
            <TableCell>Description</TableCell>
            <TableCell>Config key</TableCell>
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
                <TableCell>{tickerTypeLabel(row.ticker_type)}</TableCell>
                <TableCell>{row.frequency_weight}</TableCell>
                <TableCell>{row.sort_order}</TableCell>
                <TableCell sx={{ maxWidth: 240, wordBreak: 'break-word' }}>
                  {description}
                </TableCell>
                <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                  {tickerRowConfigKey(row)}
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
  const [edit, setEdit] = useState<TickerTapeRow | null>(null);

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

  const { enabledRows, disabledRows } = useMemo(() => {
    const enabled = rows.filter((r) => r.enabled).sort(sortById);
    const disabled = rows.filter((r) => !r.enabled).sort(sortById);
    return { enabledRows: enabled, disabledRows: disabled };
  }, [rows]);

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
          disabled={!schemas?.ticker_types.length}
        >
          Add ticker tape
        </Button>
      </CatalogPageToolbar>
      {(error || schemasError) && (
        <Alert severity="error">{error ?? schemasError}</Alert>
      )}

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Enabled
        </Typography>
        <DisplayRefreshIndicator loading={loading} />
        {enabledRows.length === 0 && !loading ? (
          <Typography variant="body2" color="text.secondary">
            No ticker tapes are enabled.
          </Typography>
        ) : layout === 'card' ? (
          <Box sx={catalogCardGridSx}>
            {enabledRows.map((r) => (
              <TickerTapeCard
                key={r.id}
                row={r}
                onEdit={() => setEdit(r)}
                onDelete={() => void deleteTape(r.id)}
              />
            ))}
          </Box>
        ) : (
          <TickerTapeTable
            rows={enabledRows}
            onEdit={setEdit}
            onDelete={(id) => void deleteTape(id)}
          />
        )}
      </Stack>

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Disabled
        </Typography>
        <DisplayRefreshIndicator loading={loading} />
        {disabledRows.length === 0 && !loading ? (
          <Typography variant="body2" color="text.secondary">
            All ticker tapes are enabled.
          </Typography>
        ) : layout === 'card' ? (
          <Box sx={catalogCardGridSx}>
            {disabledRows.map((r) => (
              <TickerTapeCard
                key={r.id}
                row={r}
                onEdit={() => setEdit(r)}
                onDelete={() => void deleteTape(r.id)}
              />
            ))}
          </Box>
        ) : (
          <TickerTapeTable
            rows={disabledRows}
            onEdit={setEdit}
            onDelete={(id) => void deleteTape(id)}
          />
        )}
      </Stack>

      {addOpen && schemas && (
        <AddTickerTapeDialog
          tickerTypes={schemas.ticker_types}
          onClose={() => setAddOpen(false)}
          onSaved={async () => {
            setAddOpen(false);
            await load();
          }}
        />
      )}

      {edit && schemas && (
        <EditTickerTapeDialog
          row={edit}
          tickerTypes={schemas.ticker_types}
          onClose={() => setEdit(null)}
          onSaved={async () => {
            setEdit(null);
            await load();
          }}
        />
      )}
    </Stack>
  );
}

function TickerTapeCard({
  row,
  onEdit,
  onDelete,
}: {
  row: TickerTapeRow;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const title = tickerRowTitle(row);
  const typeLabel = tickerTypeLabel(row.ticker_type);
  const description = tickerRowDescription(row);
  const configKey = tickerRowConfigKey(row);

  return (
    <Card
      variant="outlined"
      sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}
      aria-label={`${title} ticker tape`}
    >
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Typography variant="subtitle1" fontWeight={600} sx={{ wordBreak: 'break-word' }}>
            {title}
          </Typography>
          {tickerRowHasCustomLabel(row) ? (
            <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'monospace' }}>
              {row.id}
            </Typography>
          ) : null}
          <Chip size="small" label={typeLabel} variant="outlined" sx={{ alignSelf: 'flex-start' }} />
          <Typography variant="caption" color="text.secondary" display="block">
            Weight {row.frequency_weight} · sort {row.sort_order}
          </Typography>
          {description ? (
            <Typography
              variant="body2"
              color="text.secondary"
              sx={{
                wordBreak: 'break-word',
                display: '-webkit-box',
                WebkitLineClamp: 3,
                WebkitBoxOrient: 'vertical',
                overflow: 'hidden',
              }}
            >
              {description}
            </Typography>
          ) : null}
          {configKey ? (
            <Typography variant="caption" color="text.secondary" sx={{ wordBreak: 'break-all' }}>
              {configKey}
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
  const [configKey, setConfigKey] = useState('');
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
          config_key: configKey.trim() || null,
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
                  {m.ticker_type}
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
            label="Config key (optional, e.g. custom ticker.marquee.*)"
            value={configKey}
            onChange={(e) => setConfigKey(e.target.value)}
            fullWidth
          />
          <TextField
            label="config_json (JSON object, e.g. fallbackText for weather/news/quote)"
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
  const [configKey, setConfigKey] = useState(row.config_key ?? '');
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
          config_key: configKey.trim() || null,
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
                  {m.ticker_type}
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
            label="Config key (optional)"
            value={configKey}
            onChange={(e) => setConfigKey(e.target.value)}
            fullWidth
          />
          <TextField
            label="config_json (JSON object)"
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
