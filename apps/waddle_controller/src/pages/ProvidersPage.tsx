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
import { parseJsonObject } from '@/util/json';

type ProviderRow = {
  id: string;
  type: string;
  enabled: boolean;
  poll_seconds: number;
  base_url: string | null;
  config_json: unknown;
};

export function ProvidersPage() {
  const { active } = useDisplay();
  const [rows, setRows] = useState<ProviderRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [edit, setEdit] = useState<ProviderRow | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    setError(null);
    try {
      const res = await apiJson<{ items: ProviderRow[] }>(active, '/v1/providers');
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
        Data providers
      </Typography>
      {error && <Alert severity="error">{error}</Alert>}
      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>id</TableCell>
              <TableCell>type</TableCell>
              <TableCell>enabled</TableCell>
              <TableCell>poll (s)</TableCell>
              <TableCell>base_url</TableCell>
              <TableCell align="right"> </TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((r) => (
              <TableRow key={r.id}>
                <TableCell>{r.id}</TableCell>
                <TableCell>{r.type}</TableCell>
                <TableCell>{r.enabled ? 'yes' : 'no'}</TableCell>
                <TableCell>{r.poll_seconds}</TableCell>
                <TableCell sx={{ maxWidth: 240, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {r.base_url ?? '—'}
                </TableCell>
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
        <EditProviderDialog
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

function EditProviderDialog({
  row,
  onClose,
  onSaved,
}: {
  row: ProviderRow;
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const [enabled, setEnabled] = useState(row.enabled);
  const [poll, setPoll] = useState(row.poll_seconds);
  const [baseUrl, setBaseUrl] = useState(row.base_url ?? '');
  const [configText, setConfigText] = useState(() =>
    JSON.stringify(parseJsonObject(row.config_json), null, 2),
  );
  const [err, setErr] = useState<string | null>(null);

  const save = async () => {
    if (!active) return;
    setErr(null);
    let configJson: unknown;
    try {
      configJson = JSON.parse(configText) as unknown;
    } catch {
      setErr('config_json must be valid JSON.');
      return;
    }
    try {
      await apiFetch(active, `/v1/providers/${encodeURIComponent(row.id)}`, {
        method: 'PATCH',
        body: JSON.stringify({
          enabled,
          poll_seconds: poll,
          base_url: baseUrl.trim() || null,
          config_json: configJson,
        }),
      });
      await onSaved();
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="md">
      <DialogTitle>Edit provider {row.id}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {err && <Alert severity="error">{err}</Alert>}
          <Typography variant="body2" color="text.secondary">
            Type: {row.type}
          </Typography>
          <Stack direction="row" alignItems="center" spacing={1}>
            <Switch checked={enabled} onChange={(_, v) => setEnabled(v)} />
            <Typography>Enabled</Typography>
          </Stack>
          <TextField
            label="Poll seconds"
            type="number"
            value={poll}
            onChange={(e) => setPoll(Number(e.target.value) || 0)}
            fullWidth
          />
          <TextField
            label="Base URL"
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            fullWidth
          />
          <TextField
            label="config_json"
            value={configText}
            onChange={(e) => setConfigText(e.target.value)}
            fullWidth
            multiline
            minRows={8}
            InputProps={{ sx: { fontFamily: 'monospace', fontSize: 12 } }}
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
