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
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Switch,
  TextField,
  Typography,
} from '@mui/material';
import { CatalogPageHelp } from '@/components/CatalogPageHelp';
import { ScreenSchedulingHelpContent } from '@/components/help/ScreenSchedulingHelpContent';
import { SlideScreenPreviewIcon } from '@/icons/slideScreenPreviewIcon';
import { ScreenCarouselIcon } from '@/icons/ScreenCarouselIcon';
import { screenTypePreviewKind } from '@/util/programTelemetry';
import Form from '@rjsf/mui';
import type { IChangeEvent } from '@rjsf/core';
import type { RJSFSchema } from '@rjsf/utils';
import validator from '@rjsf/validator-ajv8';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { parseJsonObject } from '@/util/json';
import { prepareRjsfSchema } from '@/util/rjsfSchema';

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

function sortById(a: ScreenRow, b: ScreenRow): number {
  return a.id.localeCompare(b.id);
}

function screenTypeLabel(screenType: string): string {
  return screenType.replace(/_/g, ' ');
}

const catalogCardGridSx = {
  display: 'grid',
  gap: 2,
  gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
} as const;

const screenCardPreviewSx = {
  borderRadius: 1,
  bgcolor: 'action.hover',
  minHeight: 100,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
} as const;


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
      return prepareRjsfSchema(hit?.config_json_schema);
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

  const { enabledRows, disabledRows } = useMemo(() => {
    const enabled = rows.filter((r) => r.enabled).sort(sortById);
    const disabled = rows.filter((r) => !r.enabled).sort(sortById);
    return { enabledRows: enabled, disabledRows: disabled };
  }, [rows]);

  const deleteScreen = useCallback(
    async (id: string) => {
      if (!active) return;
      if (!confirm(`Delete screen ${id}?`)) return;
      try {
        await apiFetch(active, `/v1/screens/${encodeURIComponent(id)}`, {
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
      <Stack direction="row" justifyContent="flex-end">
        <Button variant="contained" onClick={() => setAddOpen(true)} disabled={!meta.length}>
          Add screen
        </Button>
      </Stack>

      {error && <Alert severity="error">{error}</Alert>}

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Enabled
        </Typography>
        {enabledRows.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            No screens are enabled.
          </Typography>
        ) : (
          <Box sx={catalogCardGridSx}>
            {enabledRows.map((r) => (
              <ScreenCard
                key={r.id}
                row={r}
                onEdit={() => setEditRow(r)}
                onDelete={() => void deleteScreen(r.id)}
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
            All screens are enabled.
          </Typography>
        ) : (
          <Box sx={catalogCardGridSx}>
            {disabledRows.map((r) => (
              <ScreenCard
                key={r.id}
                row={r}
                onEdit={() => setEditRow(r)}
                onDelete={() => void deleteScreen(r.id)}
              />
            ))}
          </Box>
        )}
      </Stack>

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
          schema={prepareRjsfSchema(editRow.config_json_schema)}
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

function ScreenCard({
  row,
  onEdit,
  onDelete,
}: {
  row: ScreenRow;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const title = row.name.trim() || row.id;
  const typeLabel = screenTypeLabel(row.screen_type);
  const previewKind = screenTypePreviewKind(row.screen_type);

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
              <ScreenCarouselIcon
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
          {row.name.trim() ? (
            <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'monospace' }}>
              {row.id}
            </Typography>
          ) : null}
          <Chip size="small" label={typeLabel} variant="outlined" sx={{ alignSelf: 'flex-start' }} />
          <Typography variant="caption" color="text.secondary" display="block">
            Dwell {row.dwell_seconds}s · weight {row.frequency_weight}
          </Typography>
          {row.description?.trim() ? (
            <Typography variant="body2" color="text.secondary" sx={{ wordBreak: 'break-word' }}>
              {row.description.trim()}
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
            fullWidth
            helperText="Seconds on screen each time this row is placed in a curated program (0 = skip automatic rotation)."
          />
          <TextField
            label="Frequency weight"
            type="number"
            value={weight}
            onChange={(e) => setWeight(Number(e.target.value) || 0)}
            fullWidth
            helperText="Higher values are chosen more often; recent appearances in the history window reduce effective weight."
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
