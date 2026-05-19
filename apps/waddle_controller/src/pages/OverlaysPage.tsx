import { useCallback, useEffect, useMemo, useState } from 'react';
import AddIcon from '@mui/icons-material/Add';
import RefreshIcon from '@mui/icons-material/Refresh';
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
  IconButton,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { CatalogPageToolbar } from '@/components/CatalogPageToolbar';
import { CatalogPageHelp } from '@/components/CatalogPageHelp';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { OverlaysHelpContent } from '@/components/help/OverlaysHelpContent';
import { OverlayConfigPanel } from '@/components/config/OverlayConfigPanel';
import { completeDialogSave } from '@/util/dialogSave';
import { parseJsonObject } from '@/util/json';
import { prepareRjsfSchema } from '@/util/rjsfSchema';
import { useConfigSchemas } from '@/hooks/useConfigSchemas';
import {
  exampleForOverlayType,
  schemaForOverlayType,
  type ConfigSchemasBundle,
  type OverlayTypeSchemaMeta,
} from '@/storage/configSchemaCache';
import { fallingImagesValidationSchema } from '@/util/fallingImagesConfigSchema';
import { floatingBalloonsValidationSchema } from '@/util/floatingBalloonsConfigSchema';
import { validateConfigAgainstSchema } from '@/util/rjsfSchema';
import { OverlayTypeIcon } from '@/util/overlayTypeIcon';
import { overlayTypeLabel, overlayTypeMetaFor } from '@/util/overlayTypeLabel';
import type { SavedDisplay } from '@/storage/displays';

type OverlayRow = {
  id: string;
  overlay_type: string;
  label: string;
  config_json: unknown;
  config_json_schema?: unknown;
  example_config_json?: unknown;
};

function sortByLabel(a: OverlayRow, b: OverlayRow): number {
  const an = a.label.trim() || a.id;
  const bn = b.label.trim() || b.id;
  return an.localeCompare(bn);
}

function parseOverlayRow(raw: Record<string, unknown>): OverlayRow | null {
  const id = typeof raw.id === 'string' ? raw.id.trim() : '';
  const overlayType =
    typeof raw.overlay_type === 'string'
      ? raw.overlay_type.trim()
      : typeof raw.overlay_kind === 'string'
        ? raw.overlay_kind.trim()
        : '';
  if (!id || !overlayType) return null;
  const label =
    typeof raw.label === 'string'
      ? raw.label
      : typeof raw.name === 'string'
        ? raw.name
        : '';
  return {
    id,
    overlay_type: overlayType,
    label,
    config_json: raw.config_json,
    config_json_schema: raw.config_json_schema,
    example_config_json: raw.example_config_json,
  };
}

function overlayTypeSchemaBundle(overlayTypes: OverlayTypeSchemaMeta[]): ConfigSchemasBundle {
  return {
    screen_types: [],
    ticker_tape_types: [],
    overlay_types: overlayTypes,
    integration_types: [],
  };
}

function exampleForType(
  overlayTypes: OverlayTypeSchemaMeta[],
): (type: string) => Record<string, unknown> {
  const bundle = overlayTypeSchemaBundle(overlayTypes);
  return (type: string) => parseJsonObject(exampleForOverlayType(bundle, type));
}

function schemaForType(overlayTypes: OverlayTypeSchemaMeta[], type: string): unknown {
  return schemaForOverlayType(overlayTypeSchemaBundle(overlayTypes), type);
}

function configPreview(row: OverlayRow): string {
  const cfg = parseJsonObject(row.config_json);
  if (row.overlay_type === 'edge_glow') {
    const color = typeof cfg.color === 'string' ? cfg.color : '';
    const intensity = typeof cfg.intensity === 'number' ? cfg.intensity : null;
    const parts = [color, intensity != null ? `intensity ${intensity.toFixed(2)}` : ''].filter(
      Boolean,
    );
    return parts.length > 0 ? parts.join(' · ') : '—';
  }
  const shapes = cfg.shapes;
  if (Array.isArray(shapes) && shapes.length > 0) {
    return shapes.filter((s) => typeof s === 'string').join(', ');
  }
  const messages = cfg.messages;
  if (Array.isArray(messages) && messages.length > 0) {
    const first = messages.find((m) => typeof m === 'string' && m.trim());
    if (typeof first === 'string') return first.trim();
  }
  const keys = Object.keys(cfg).filter((k) => k !== 'messages');
  if (keys.length === 0) return '—';
  return keys.slice(0, 3).join(', ');
}

const FALLING_IMAGES_CONFIG_KEYS = [
  'image_blob_keys',
  'drop_interval_sec',
  'fall_speed',
  'image_scale',
  'scale_jitter',
] as const;

function fallingImagesConfigFromForm(form: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const key of FALLING_IMAGES_CONFIG_KEYS) {
    if (key in form) {
      out[key] = form[key];
    }
  }
  return out;
}

function stripMessagesFromConfig(form: Record<string, unknown>): Record<string, unknown> {
  const { messages: _messages, ...rest } = form;
  return rest;
}

function overlayConfigForSubmit(
  overlayType: string,
  form: Record<string, unknown>,
): Record<string, unknown> {
  const t = overlayType.trim();
  if (t === 'shape_rain' || t === 'hearts_rain') {
    const shapes = form.shapes;
    return {
      shapes: Array.isArray(shapes)
        ? shapes.filter((s): s is string => typeof s === 'string' && s.trim().length > 0)
        : [],
    };
  }
  if (t === 'falling_images') {
    return fallingImagesConfigFromForm(stripMessagesFromConfig(form));
  }
  return form;
}

function overlayConfigForForm(overlayType: string, raw: Record<string, unknown>): Record<string, unknown> {
  if (overlayType.trim() === 'falling_images') {
    return stripMessagesFromConfig(raw);
  }
  return raw;
}

const overlayCardPreviewSx = {
  borderRadius: 1,
  bgcolor: 'action.hover',
  minHeight: 88,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
} as const;

type OverlayDialogMode = 'create' | 'edit';

function OverlayDialog({
  open,
  mode,
  active,
  initial,
  overlayTypes,
  onClose,
  onSaved,
}: {
  open: boolean;
  mode: OverlayDialogMode;
  active: SavedDisplay;
  initial: OverlayRow | null;
  overlayTypes: OverlayTypeSchemaMeta[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [saving, setSaving] = useState(false);
  const [localErr, setLocalErr] = useState<string | null>(null);
  const [label, setLabel] = useState('');
  const [overlayType, setOverlayType] = useState(overlayTypes[0]?.overlay_type ?? 'shape_rain');
  const [configForm, setConfigForm] = useState<Record<string, unknown>>({});

  const exampleFor = useMemo(() => exampleForType(overlayTypes), [overlayTypes]);

  useEffect(() => {
    if (!open) return;
    setLocalErr(null);
    if (initial) {
      setLabel(initial.label);
      setOverlayType(initial.overlay_type);
      setConfigForm(
        overlayConfigForForm(initial.overlay_type, parseJsonObject(initial.config_json)),
      );
    } else {
      setLabel('');
      setOverlayType(overlayTypes[0]?.overlay_type ?? 'shape_rain');
      setConfigForm(exampleFor(overlayTypes[0]?.overlay_type ?? 'shape_rain'));
    }
  }, [open, initial, overlayTypes, exampleFor]);

  const configSchema = useMemo(
    () => prepareRjsfSchema(schemaForType(overlayTypes, overlayType)),
    [overlayTypes, overlayType],
  );

  const handleTypeChange = (next: string) => {
    setOverlayType(next);
    if (mode === 'create') {
      setConfigForm(overlayConfigForForm(next, exampleFor(next)));
    }
  };

  const submit = async () => {
    setLocalErr(null);
    const labelTrim = label.trim();
    if (!labelTrim) {
      setLocalErr('Label is required.');
      return;
    }
    const configPayload = overlayConfigForSubmit(overlayType, configForm);
    const validationSchema =
      overlayType === 'falling_images'
        ? fallingImagesValidationSchema
        : overlayType === 'floating_balloons'
          ? floatingBalloonsValidationSchema
          : configSchema;
    const validationErrors = validateConfigAgainstSchema(configPayload, validationSchema);
    if (validationErrors.length > 0) {
      setLocalErr(validationErrors[0] ?? 'Invalid configuration.');
      return;
    }
    if (
      (overlayType === 'shape_rain' || overlayType === 'hearts_rain') &&
      (!Array.isArray(configPayload.shapes) || configPayload.shapes.length === 0)
    ) {
      setLocalErr('Select at least one shape.');
      return;
    }
    setSaving(true);
    try {
      if (mode === 'create') {
        await apiFetch(active, '/v1/display/overlays', {
          method: 'POST',
          body: JSON.stringify({
            label: labelTrim,
            overlay_type: overlayType.trim(),
            config_json: configPayload,
          }),
        });
      } else if (initial) {
        await apiFetch(active, `/v1/display/overlays/${encodeURIComponent(initial.id)}`, {
          method: 'PATCH',
          body: JSON.stringify({
            label: labelTrim,
            overlay_type: overlayType.trim(),
            config_json: configPayload,
          }),
        });
      }
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      setLocalErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle>{mode === 'create' ? 'New overlay' : 'Edit overlay'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {localErr && <Alert severity="error">{localErr}</Alert>}
          <TextField
            label="Label"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            required
            fullWidth
            autoFocus
          />
          <FormControl fullWidth>
            <InputLabel id="overlay-type-label">Overlay type</InputLabel>
            <Select
              labelId="overlay-type-label"
              label="Overlay type"
              value={overlayType}
              onChange={(e) => handleTypeChange(String(e.target.value))}
              disabled={mode === 'edit'}
            >
              {overlayTypes.map((m) => (
                <MenuItem key={m.overlay_type} value={m.overlay_type}>
                  {overlayTypeLabel(m.overlay_type, m)}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          {mode === 'edit' ? (
            <Typography variant="caption" color="text.secondary">
              Overlay type cannot be changed after create. Delete and add a new overlay to switch
              types.
            </Typography>
          ) : null}
          <OverlayConfigPanel
            display={active}
            overlayType={overlayType}
            schema={configSchema}
            formData={configForm}
            onChange={setConfigForm}
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={() => void submit()} disabled={saving}>
          {saving ? 'Saving…' : 'Save'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}

function OverlayTable({
  rows,
  overlayTypes,
  canWrite,
  onEdit,
  onDelete,
}: {
  rows: OverlayRow[];
  overlayTypes: OverlayTypeSchemaMeta[];
  canWrite: boolean;
  onEdit: (row: OverlayRow) => void;
  onDelete: (id: string) => void;
}) {
  return (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Name</TableCell>
            <TableCell>Type</TableCell>
            <TableCell>Configuration</TableCell>
            {canWrite ? <TableCell align="right">Actions</TableCell> : null}
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row) => (
            <TableRow key={row.id} hover>
              <TableCell sx={{ fontWeight: 600 }}>{row.label.trim() || row.id}</TableCell>
              <TableCell>
                <Chip
                  size="small"
                  icon={<OverlayTypeIcon overlayType={row.overlay_type} />}
                  label={overlayTypeLabel(
                    row.overlay_type,
                    overlayTypeMetaFor(overlayTypes, row.overlay_type),
                  )}
                />
              </TableCell>
              <TableCell sx={{ maxWidth: 280 }}>{configPreview(row)}</TableCell>
              {canWrite ? (
                <TableCell align="right">
                  <Button size="small" onClick={() => onEdit(row)}>
                    Edit
                  </Button>
                  <Button size="small" color="error" onClick={() => onDelete(row.id)}>
                    Delete
                  </Button>
                </TableCell>
              ) : null}
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

function OverlayCard({
  row,
  overlayTypes,
  canWrite,
  onEdit,
  onDelete,
}: {
  row: OverlayRow;
  overlayTypes: OverlayTypeSchemaMeta[];
  canWrite: boolean;
  onEdit: () => void;
  onDelete: () => void;
}) {
  return (
    <Card variant="outlined" sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Box sx={overlayCardPreviewSx}>
            <OverlayTypeIcon
              overlayType={row.overlay_type}
              sx={{ fontSize: 56, color: 'primary.main', opacity: 0.72 }}
            />
          </Box>
          <Typography variant="subtitle1" fontWeight={600}>
            {row.label.trim() || row.id}
          </Typography>
          <Chip
            size="small"
            variant="outlined"
            icon={<OverlayTypeIcon overlayType={row.overlay_type} />}
            label={overlayTypeLabel(
              row.overlay_type,
              overlayTypeMetaFor(overlayTypes, row.overlay_type),
            )}
            sx={{ alignSelf: 'flex-start' }}
          />
          <Typography variant="body2" color="text.secondary">
            {configPreview(row)}
          </Typography>
        </Stack>
      </CardContent>
      {canWrite ? (
        <CardActions>
          <Button size="small" onClick={onEdit}>
            Edit
          </Button>
          <Button size="small" color="error" onClick={onDelete}>
            Delete
          </Button>
        </CardActions>
      ) : null}
    </Card>
  );
}

export function OverlaysPage() {
  const { active } = useDisplay();
  const { layout, setLayout } = useListLayoutPreference('overlays');
  const { hasPermission } = useAuth();
  const canWrite = hasPermission('overlays.write');
  const [rawItems, setRawItems] = useState<Record<string, unknown>[]>([]);
  const { schemas, error: schemasError } = useConfigSchemas(active);
  const [error, setError] = useState<string | null>(null);
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [dialogMode, setDialogMode] = useState<OverlayDialogMode>('create');
  const [dialogInitial, setDialogInitial] = useState<OverlayRow | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const overlaysRes = await apiJson<{ items: Record<string, unknown>[] }>(
          active,
          '/v1/display/overlays',
        );
        setRawItems(overlaysRes.items ?? []);
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    });
  }, [active, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load]);

  const { rows, skipped } = useMemo(() => {
    const parsed: OverlayRow[] = [];
    let bad = 0;
    for (const raw of rawItems) {
      const row = parseOverlayRow(raw);
      if (row) parsed.push(row);
      else bad += 1;
    }
    parsed.sort(sortByLabel);
    return { rows: parsed, skipped: bad };
  }, [rawItems]);

  const deleteRow = useCallback(
    async (id: string) => {
      if (!active) return;
      const row = rows.find((r) => r.id === id);
      const title = row?.label.trim() || id;
      if (!window.confirm(`Delete overlay “${title}”?`)) return;
      setError(null);
      try {
        await apiFetch(active, `/v1/display/overlays/${encodeURIComponent(id)}`, {
          method: 'DELETE',
        });
        await load();
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    },
    [active, load, rows],
  );

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  const openCreate = () => {
    setDialogMode('create');
    setDialogInitial(null);
    setDialogOpen(true);
  };

  const openEdit = (row: OverlayRow) => {
    setDialogMode('edit');
    setDialogInitial(row);
    setDialogOpen(true);
  };

  return (
    <Stack spacing={3}>
      <DisplayRefreshIndicator loading={loading} />
      <Box>
        <Stack direction="row" alignItems="center" spacing={0.25} sx={{ mb: 0.5 }}>
          <Typography variant="h6" fontWeight={600}>
            Overlays
          </Typography>
          <CatalogPageHelp title="Overlays">
            <OverlaysHelpContent />
          </CatalogPageHelp>
        </Stack>
        <Typography variant="body2" color="text.secondary">
          Define celebration overlay effects (confetti, hearts, bouncing text, falling images).
          Attach overlays to curator programs on the Curators page; schedule when they run using
          curator schedule rules.
        </Typography>
      </Box>
      <CatalogPageToolbar layout={layout} onLayoutChange={setLayout}>
        {canWrite && (
          <Button startIcon={<AddIcon />} variant="contained" onClick={openCreate}>
            Add overlay
          </Button>
        )}
        <Tooltip title="Reload overlays">
          <span>
            <IconButton onClick={() => void load()} disabled={loading} aria-label="Reload overlays">
              <RefreshIcon />
            </IconButton>
          </span>
        </Tooltip>
      </CatalogPageToolbar>

      {(error || schemasError) && (
        <Alert severity="error">{error ?? schemasError}</Alert>
      )}
      {skipped > 0 && (
        <Alert severity="warning">
          Skipped {skipped} row(s) with missing or invalid data.
        </Alert>
      )}

      {rows.length === 0 && !error && !loading ? (
        <Typography variant="body2" color="text.secondary">
          No overlays defined yet.
        </Typography>
      ) : layout === 'card' ? (
        <Box sx={catalogCardGridSx}>
          {rows.map((row) => (
            <OverlayCard
              key={row.id}
              row={row}
              overlayTypes={schemas?.overlay_types ?? []}
              canWrite={canWrite}
              onEdit={() => openEdit(row)}
              onDelete={() => void deleteRow(row.id)}
            />
          ))}
        </Box>
      ) : (
        <OverlayTable
          rows={rows}
          overlayTypes={schemas?.overlay_types ?? []}
          canWrite={canWrite}
          onEdit={openEdit}
          onDelete={(id) => void deleteRow(id)}
        />
      )}

      {schemas && (
        <OverlayDialog
          open={dialogOpen}
          mode={dialogMode}
          active={active}
          initial={dialogInitial}
          overlayTypes={schemas.overlay_types}
          onClose={() => setDialogOpen(false)}
          onSaved={() => void load()}
        />
      )}
    </Stack>
  );
}
