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
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { CatalogPageToolbar } from '@/components/CatalogPageToolbar';
import { CatalogPageHelp } from '@/components/CatalogPageHelp';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
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
  screen_type: string;
  config_json: string;
  config_json_schema?: string;
  example_config_json?: string;
  min_dwell_seconds: number;
  max_dwell_seconds: number;
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
  onEdit,
  onDelete,
}: {
  rows: ScreenRow[];
  onEdit: (row: ScreenRow) => void;
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
            <TableCell>Dwell (min–max)</TableCell>
            <TableCell>Weight</TableCell>
            <TableCell>Gap</TableCell>
            <TableCell>Description</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row) => {
            const title = row.name.trim() || row.id;
            return (
              <TableRow key={row.id} hover>
                <TableCell sx={{ fontWeight: row.name.trim() ? 600 : 400 }}>{title}</TableCell>
                <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>{row.id}</TableCell>
                <TableCell>{screenTypeLabel(row.screen_type)}</TableCell>
                <TableCell>
                  {row.min_dwell_seconds}–{row.max_dwell_seconds}s
                </TableCell>
                <TableCell>{row.frequency_weight}</TableCell>
                <TableCell>{row.min_gap_between_shows_seconds}s</TableCell>
                <TableCell sx={{ maxWidth: 280, wordBreak: 'break-word' }}>
                  {row.description?.trim() ?? ''}
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
  const { active } = useDisplay();
  const { loading, wrapRefresh } = useDisplayRefresh();
  const { layout, setLayout } = useListLayoutPreference('screens');
  const [rows, setRows] = useState<ScreenRow[]>([]);
  const [meta, setMeta] = useState<ScreenTypeMeta[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [editRow, setEditRow] = useState<ScreenRow | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    await wrapRefresh(async () => {
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
    });
  }, [active, wrapRefresh]);

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

  const sortedRows = useMemo(() => [...rows].sort(sortById), [rows]);

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
      <CatalogPageToolbar layout={layout} onLayoutChange={setLayout}>
        <Button variant="contained" onClick={() => setAddOpen(true)} disabled={!meta.length}>
          Add screen
        </Button>
      </CatalogPageToolbar>

      {error && <Alert severity="error">{error}</Alert>}

      {sortedRows.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          No screens in the catalog yet.
        </Typography>
      ) : layout === 'card' ? (
        <Box sx={catalogCardGridSx}>
          {sortedRows.map((r) => (
            <ScreenCard
              key={r.id}
              row={r}
              onEdit={() => setEditRow(r)}
              onDelete={() => void deleteScreen(r.id)}
            />
          ))}
        </Box>
      ) : (
        <ScreenTable
          rows={sortedRows}
          onEdit={setEditRow}
          onDelete={(id) => void deleteScreen(id)}
        />
      )}

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
            Dwell {row.min_dwell_seconds}–{row.max_dwell_seconds}s · weight {row.frequency_weight} ·
            gap {row.min_gap_between_shows_seconds}s
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
  const [minDwell, setMinDwell] = useState(row.min_dwell_seconds);
  const [maxDwell, setMaxDwell] = useState(row.max_dwell_seconds);
  const [weight, setWeight] = useState(row.frequency_weight);
  const [minGap, setMinGap] = useState(row.min_gap_between_shows_seconds);
  const [minPlacements, setMinPlacements] = useState(row.min_placements_per_program);
  const [maxPlacements, setMaxPlacements] = useState<number | ''>(
    row.max_placements_per_program ?? '',
  );
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
          min_dwell_seconds: minDwell,
          max_dwell_seconds: maxDwell,
          frequency_weight: weight,
          min_gap_between_shows_seconds: minGap,
          min_placements_per_program: minPlacements,
          max_placements_per_program:
            maxPlacements === '' ? null : Number(maxPlacements),
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
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
            <TextField
              label="Min dwell seconds"
              type="number"
              value={minDwell}
              onChange={(e) => setMinDwell(Number(e.target.value) || 0)}
              fullWidth
            />
            <TextField
              label="Max dwell seconds"
              type="number"
              value={maxDwell}
              onChange={(e) => setMaxDwell(Number(e.target.value) || 0)}
              fullWidth
            />
          </Stack>
          <TextField
            label="Frequency weight"
            type="number"
            value={weight}
            onChange={(e) => setWeight(Number(e.target.value) || 0)}
            fullWidth
            helperText="Higher values are chosen more often; recent appearances in the history window reduce effective weight."
          />
          <TextField
            label="Min gap between shows (seconds)"
            type="number"
            value={minGap}
            onChange={(e) => setMinGap(Number(e.target.value) || 0)}
            fullWidth
            helperText="Minimum time since the last showing before this screen is eligible again."
          />
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
            <TextField
              label="Min placements per program"
              type="number"
              value={minPlacements}
              onChange={(e) => setMinPlacements(Number(e.target.value) || 0)}
              fullWidth
            />
            <TextField
              label="Max placements per program"
              type="number"
              value={maxPlacements}
              onChange={(e) =>
                setMaxPlacements(e.target.value === '' ? '' : Number(e.target.value) || 0)
              }
              fullWidth
              helperText="Leave empty for no cap."
            />
          </Stack>
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
