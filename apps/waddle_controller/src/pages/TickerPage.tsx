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
} from '@mui/material';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';

type TickerDef = {
  id: string;
  name: string;
  description: string;
  enabled: boolean;
  ticker_type: string;
  frequency_weight: number;
  sort_order: number;
  config_key: string | null;
};

export function TickerPage() {
  const { active } = useDisplay();
  const [rows, setRows] = useState<TickerDef[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [edit, setEdit] = useState<TickerDef | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    setError(null);
    try {
      const res = await apiJson<{ items: TickerDef[] }>(active, '/v1/ticker/definitions');
      setRows(res.items ?? []);
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
      <Typography variant="h5" fontWeight={600}>
        Ticker definitions
      </Typography>
      {error && <Alert severity="error">{error}</Alert>}
      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>id</TableCell>
              <TableCell>name</TableCell>
              <TableCell>type</TableCell>
              <TableCell>enabled</TableCell>
              <TableCell>weight</TableCell>
              <TableCell>sort</TableCell>
              <TableCell align="right"> </TableCell>
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
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {edit && (
        <EditTickerDialog
          row={edit}
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

function EditTickerDialog({
  row,
  onClose,
  onSaved,
}: {
  row: TickerDef;
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const [enabled, setEnabled] = useState(row.enabled);
  const [weight, setWeight] = useState(row.frequency_weight);
  const [sort, setSort] = useState(row.sort_order);
  const [configKey, setConfigKey] = useState(row.config_key ?? '');
  const [err, setErr] = useState<string | null>(null);

  const save = async () => {
    if (!active) return;
    setErr(null);
    try {
      await apiFetch(active, `/v1/ticker/definitions/${encodeURIComponent(row.id)}`, {
        method: 'PATCH',
        body: JSON.stringify({
          enabled,
          frequency_weight: weight,
          sort_order: sort,
          config_key: configKey.trim() || null,
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
