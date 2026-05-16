import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
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
  Paper,
} from '@mui/material';
import Form from '@rjsf/mui';
import type { IChangeEvent } from '@rjsf/core';
import type { RJSFSchema } from '@rjsf/utils';
import validator from '@rjsf/validator-ajv8';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { parseJsonObject } from '@/util/json';

type ScreenRow = {
  id: string;
  name: string;
  description?: string;
  enabled: boolean;
  screen_type: string;
  config_json: string;
  config_json_schema?: string;
  example_config_json?: string;
  dwell_seconds: number;
  frequency_weight: number;
  min_gap_between_shows_seconds: number;
  min_placements_per_program: number;
  max_placements_per_program?: number | null;
  data_key: string;
};

type ScreenTypeMeta = {
  screen_type: string;
  config_json_schema: unknown;
  example_config_json: unknown;
};

function schemaObject(raw: unknown): RJSFSchema {
  const o = parseJsonObject(raw);
  if (Object.keys(o).length > 0) {
    return o as RJSFSchema;
  }
  return { type: 'object', additionalProperties: true } as RJSFSchema;
}

export function ScreensPage() {
  const { active } = useDisplay();
  const [rows, setRows] = useState<ScreenRow[]>([]);
  const [meta, setMeta] = useState<ScreenTypeMeta[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [editRow, setEditRow] = useState<ScreenRow | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    setError(null);
    try {
      const [s, m] = await Promise.all([
        apiJson<{ items: ScreenRow[] }>(active, '/v1/screens'),
        apiJson<{ items: ScreenTypeMeta[] }>(active, '/v1/meta/screen-types'),
      ]);
      setRows(s.items ?? []);
      setMeta(m.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  }, [active]);

  useEffect(() => {
    void load();
  }, [load]);

  const schemaForType = useCallback(
    (screenType: string) => {
      const hit = meta.find((m) => m.screen_type === screenType);
      return schemaObject(hit?.config_json_schema);
    },
    [meta],
  );

  const exampleForType = useCallback(
    (screenType: string) => {
      const hit = meta.find((m) => m.screen_type === screenType);
      return parseJsonObject(hit?.example_config_json);
    },
    [meta],
  );

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={2}>
      <Stack direction="row" justifyContent="space-between" alignItems="center">
        <Typography variant="h5" fontWeight={600}>
          Screens
        </Typography>
        <Button variant="contained" onClick={() => setAddOpen(true)} disabled={!meta.length}>
          Add screen
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
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((r) => (
              <TableRow key={r.id}>
                <TableCell>{r.id}</TableCell>
                <TableCell>{r.name}</TableCell>
                <TableCell>{r.screen_type}</TableCell>
                <TableCell>{r.enabled ? 'yes' : 'no'}</TableCell>
                <TableCell align="right">
                  <Button size="small" onClick={() => setEditRow(r)}>
                    Edit
                  </Button>
                  <Button
                    size="small"
                    color="error"
                    onClick={async () => {
                      if (!confirm(`Delete screen ${r.id}?`)) return;
                      try {
                        await apiFetch(active, `/v1/screens/${encodeURIComponent(r.id)}`, {
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
        <AddScreenDialog
          meta={meta}
          schemaForType={schemaForType}
          exampleForType={exampleForType}
          onClose={() => setAddOpen(false)}
          onSaved={async () => {
            setAddOpen(false);
            await load();
          }}
        />
      )}

      {editRow && (
        <EditScreenDialog
          row={editRow}
          schema={schemaObject(editRow.config_json_schema)}
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

function AddScreenDialog({
  meta,
  schemaForType,
  exampleForType,
  onClose,
  onSaved,
}: {
  meta: ScreenTypeMeta[];
  schemaForType: (t: string) => RJSFSchema;
  exampleForType: (t: string) => Record<string, unknown>;
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const [id, setId] = useState('');
  const [screenType, setScreenType] = useState(meta[0]?.screen_type ?? '');
  const [formData, setFormData] = useState<Record<string, unknown>>(() =>
    exampleForType(meta[0]?.screen_type ?? ''),
  );
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    setFormData(exampleForType(screenType));
  }, [screenType, exampleForType]);

  const schema = useMemo(() => schemaForType(screenType), [schemaForType, screenType]);

  const submit = async ({ formData: fd }: IChangeEvent<Record<string, unknown>>) => {
    if (!active) return;
    setErr(null);
    const tid = id.trim();
    if (!tid) {
      setErr('Screen id is required.');
      return;
    }
    try {
      await apiFetch(active, '/v1/screens', {
        method: 'POST',
        body: JSON.stringify({
          id: tid,
          screen_type: screenType,
          config_json: fd,
        }),
      });
      await onSaved();
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  return (
    <Dialog open fullWidth maxWidth="md" onClose={onClose}>
      <DialogTitle>Add screen</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {err && <Alert severity="error">{err}</Alert>}
          <TextField label="Screen id" value={id} onChange={(e) => setId(e.target.value)} required />
          <FormControl fullWidth>
            <InputLabel id="st">Screen type</InputLabel>
            <Select
              labelId="st"
              label="Screen type"
              value={screenType}
              onChange={(e) => setScreenType(String(e.target.value))}
            >
              {meta.map((m) => (
                <MenuItem key={m.screen_type} value={m.screen_type}>
                  {m.screen_type}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <Box sx={{ '& .MuiFormControl-root': { mb: 1 } }}>
            <Form
              schema={schema}
              formData={formData}
              validator={validator}
              onChange={(e) => setFormData(e.formData)}
              onSubmit={submit}
            >
              <Stack direction="row" spacing={1} sx={{ mt: 2, justifyContent: 'flex-end' }}>
                <Button type="button" onClick={onClose}>
                  Cancel
                </Button>
                <Button type="submit" variant="contained">
                  Create
                </Button>
              </Stack>
            </Form>
          </Box>
        </Stack>
      </DialogContent>
    </Dialog>
  );
}

function EditScreenDialog({
  row,
  schema,
  onClose,
  onSaved,
}: {
  row: ScreenRow;
  schema: RJSFSchema;
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const [name, setName] = useState(row.name);
  const [enabled, setEnabled] = useState(row.enabled);
  const [dwell, setDwell] = useState(row.dwell_seconds);
  const [weight, setWeight] = useState(row.frequency_weight);
  const [formData, setFormData] = useState<Record<string, unknown>>(() =>
    parseJsonObject(row.config_json),
  );
  const [err, setErr] = useState<string | null>(null);

  const submit = async () => {
    if (!active) return;
    setErr(null);
    try {
      await apiFetch(active, `/v1/screens/${encodeURIComponent(row.id)}`, {
        method: 'PATCH',
        body: JSON.stringify({
          name,
          enabled,
          dwell_seconds: dwell,
          frequency_weight: weight,
          config_json: formData,
        }),
      });
      await onSaved();
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  return (
    <Dialog open fullWidth maxWidth="md" onClose={onClose}>
      <DialogTitle>Edit {row.id}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {err && <Alert severity="error">{err}</Alert>}
          <TextField label="Name" value={name} onChange={(e) => setName(e.target.value)} fullWidth />
          <Stack direction="row" alignItems="center" spacing={1}>
            <Switch checked={enabled} onChange={(_, v) => setEnabled(v)} />
            <Typography>Enabled</Typography>
          </Stack>
          <TextField
            label="Dwell seconds"
            type="number"
            value={dwell}
            onChange={(e) => setDwell(Number(e.target.value) || 0)}
          />
          <TextField
            label="Frequency weight"
            type="number"
            value={weight}
            onChange={(e) => setWeight(Number(e.target.value) || 0)}
          />
          <Typography variant="subtitle2">config.json</Typography>
          <Form
            schema={schema}
            formData={formData}
            validator={validator}
            onChange={(e) => setFormData(e.formData)}
          >
            <Box sx={{ display: 'none' }}>
              <button type="submit" />
            </Box>
          </Form>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={() => void submit()}>
          Save
        </Button>
      </DialogActions>
    </Dialog>
  );
}
