import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Button,
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
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';

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

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={2}>
      <Stack direction="row" justifyContent="space-between" alignItems="center">
        <Typography variant="h5" fontWeight={600}>
          Ticker tapes
        </Typography>
        <Button variant="contained" onClick={() => setAddOpen(true)} disabled={!meta.length}>
          Add ticker tape
        </Button>
      </Stack>
      {error && <Alert severity="error">{error}</Alert>}
      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>ID</TableCell>
              <TableCell>Name</TableCell>
              <TableCell>Type</TableCell>
              <TableCell>Enabled</TableCell>
              <TableCell>Weight</TableCell>
              <TableCell>Sort</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((r) => (
              <TableRow key={r.id}>
                <TableCell>{r.id}</TableCell>
                <TableCell>{r.name}</TableCell>
                <TableCell>{r.ticker_type}</TableCell>
                <TableCell>{r.enabled ? 'yes' : 'no'}</TableCell>
                <TableCell>{r.frequency_weight}</TableCell>
                <TableCell>{r.sort_order}</TableCell>
                <TableCell align="right">
                  <Button size="small" onClick={() => setEdit(r)}>
                    Edit
                  </Button>
                  <Button
                    size="small"
                    color="error"
                    onClick={async () => {
                      if (!confirm(`Delete ticker tape ${r.id}?`)) return;
                      try {
                        await apiFetch(active, `/v1/ticker/tapes/${encodeURIComponent(r.id)}`, {
                          method: 'DELETE',
                        });
                        await load();
                      } catch (e) {
                        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
                      }
                    }}
                  >
                    Delete
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

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
          />
          <TextField
            label="Sort order"
            type="number"
            value={sort}
            onChange={(e) => setSort(Number(e.target.value) || 0)}
            fullWidth
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
          />
          <TextField
            label="Sort order"
            type="number"
            value={sort}
            onChange={(e) => setSort(Number(e.target.value) || 0)}
            fullWidth
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
