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
  Stack,
  Switch,
  TextField,
  Typography,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
} from '@mui/material';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { CatalogPageHelp } from '@/components/CatalogPageHelp';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { TickerTapesHelpContent } from '@/components/help/TickerTapesHelpContent';

type TickerTapeRow = {
  id: string;
  name: string;
  description: string;
  enabled: boolean;
  ticker_type: string;
  frequency_weight: number;
  sort_order: number;
  config_key: string | null;
  config_json?: unknown;
  config_json_schema?: unknown;
  example_config_json?: unknown;
};

type TickerTypeMeta = {
  ticker_type: string;
  config_json_schema: unknown;
  example_config_json: unknown;
};

function sortById(a: TickerTapeRow, b: TickerTapeRow): number {
  return a.id.localeCompare(b.id);
}

function tickerTypeLabel(tickerType: string): string {
  return tickerType.replace(/_/g, ' ');
}

const catalogCardGridSx = {
  display: 'grid',
  gap: 2,
  gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
} as const;

export function TickerPage() {
  const { active } = useDisplay();
  const [rows, setRows] = useState<TickerTapeRow[]>([]);
  const [meta, setMeta] = useState<TickerTypeMeta[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [edit, setEdit] = useState<TickerTapeRow | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    setError(null);
    try {
      const [tapes, types] = await Promise.all([
        apiJson<{ items: TickerTapeRow[] }>(active, '/v1/ticker/tapes'),
        apiJson<{ items: TickerTypeMeta[] }>(active, '/v1/meta/ticker-types'),
      ]);
      setRows(tapes.items ?? []);
      setMeta(types.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  }, [active]);

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
      <Stack direction="row" justifyContent="flex-end">
        <Button variant="contained" onClick={() => setAddOpen(true)} disabled={!meta.length}>
          Add ticker tape
        </Button>
      </Stack>
      {error && <Alert severity="error">{error}</Alert>}

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Enabled
        </Typography>
        {enabledRows.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            No ticker tapes are enabled.
          </Typography>
        ) : (
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
        )}
      </Stack>

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Disabled
        </Typography>
        {disabledRows.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            All ticker tapes are enabled.
          </Typography>
        ) : (
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
        )}
      </Stack>

      {addOpen && (
        <AddTickerTapeDialog
          meta={meta}
          onClose={() => setAddOpen(false)}
          onSaved={async () => {
            setAddOpen(false);
            await load();
          }}
        />
      )}

      {edit && (
        <EditTickerTapeDialog
          row={edit}
          meta={meta}
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
  const title = row.name.trim() || row.id;
  const typeLabel = tickerTypeLabel(row.ticker_type);

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
          {row.name.trim() ? (
            <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'monospace' }}>
              {row.id}
            </Typography>
          ) : null}
          <Chip size="small" label={typeLabel} variant="outlined" sx={{ alignSelf: 'flex-start' }} />
          <Typography variant="caption" color="text.secondary" display="block">
            Weight {row.frequency_weight} · sort {row.sort_order}
          </Typography>
          {row.description.trim() ? (
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
              {row.description.trim()}
            </Typography>
          ) : null}
          {row.config_key?.trim() ? (
            <Typography variant="caption" color="text.secondary" sx={{ wordBreak: 'break-all' }}>
              {row.config_key.trim()}
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
  meta,
  onClose,
  onSaved,
}: {
  meta: TickerTypeMeta[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const [id, setId] = useState('');
  const [tickerType, setTickerType] = useState(meta[0]?.ticker_type ?? '');
  const [name, setName] = useState('');
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
          name: name.trim() || undefined,
          description: description.trim(),
          enabled,
          frequency_weight: weight,
          sort_order: sort,
          config_key: configKey.trim() || null,
          config_json: configJson,
        }),
      });
      await onSaved();
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
              {meta.map((m) => (
                <MenuItem key={m.ticker_type} value={m.ticker_type}>
                  {m.ticker_type}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <TextField label="Name (optional)" value={name} onChange={(e) => setName(e.target.value)} fullWidth />
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
  meta,
  onClose,
  onSaved,
}: {
  row: TickerTapeRow;
  meta: TickerTypeMeta[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const [name, setName] = useState(row.name);
  const [description, setDescription] = useState(row.description);
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
          name: name.trim(),
          description: description.trim(),
          ticker_type: tickerType,
          enabled,
          frequency_weight: weight,
          sort_order: sort,
          config_key: configKey.trim() || null,
          config_json: configJson,
        }),
      });
      await onSaved();
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
              {meta.map((m) => (
                <MenuItem key={m.ticker_type} value={m.ticker_type}>
                  {m.ticker_type}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <TextField label="Name" value={name} onChange={(e) => setName(e.target.value)} fullWidth />
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
