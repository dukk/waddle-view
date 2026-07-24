import { useCallback, useEffect, useMemo, useState } from 'react';
import AddIcon from '@mui/icons-material/Add';
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
  ListSubheader,
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
  Typography,
} from '@mui/material';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { CatalogDisplayTransferPanel } from '@/components/catalog/CatalogDisplayTransferPanel';
import { CatalogListWithTransferSection } from '@/components/catalog/CatalogListWithTransferSection';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { DataViewEmptyState } from '@/components/dataView/DataViewEmptyState';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { useClientDataView } from '@/hooks/useClientDataView';
import { useConfirmDialog } from '@/hooks/useConfirmDialog';
import type { SortOption } from '@/util/clientListPipeline';
import { CatalogPageHelp } from '@/components/CatalogPageHelp';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { OverlaysHelpContent } from '@/components/help/OverlaysHelpContent';
import type { ContentCategoryOption } from '@/components/CategoryMultiSelect';
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
import { overlayIdFromLabel } from '@/util/catalogIdFromLabel';
import {
  groupOverlayTypesByCategory,
  overlayCategoryLabel,
  overlayTypeCategory,
  partitionOverlayRowsByCategory,
} from '@/util/overlayTypeCategory';
import { syncQrOverlayFormData } from '@/util/qrOverlayPayload';
import type { SavedDisplay } from '@/storage/displays';

type OverlayRow = {
  id: string;
  overlay_type: string;
  label: string;
  description?: string;
  config_json: unknown;
  config_json_schema?: unknown;
  example_config_json?: unknown;
};

function overlayRowTitle(row: OverlayRow): string {
  return row.label.trim() || row.id;
}

const OVERLAY_SORT_OPTIONS: SortOption<OverlayRow>[] = [
  {
    id: 'label_asc',
    label: 'Name (A–Z)',
    compare: (a, b) => overlayRowTitle(a).localeCompare(overlayRowTitle(b)),
  },
  {
    id: 'label_desc',
    label: 'Name (Z–A)',
    compare: (a, b) => overlayRowTitle(b).localeCompare(overlayRowTitle(a)),
  },
  {
    id: 'type_asc',
    label: 'Type (A–Z)',
    compare: (a, b) => a.overlay_type.localeCompare(b.overlay_type),
  },
  {
    id: 'type_desc',
    label: 'Type (Z–A)',
    compare: (a, b) => b.overlay_type.localeCompare(a.overlay_type),
  },
];

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
  const description =
    typeof raw.description === 'string' ? raw.description : '';
  return {
    id,
    overlay_type: overlayType,
    label,
    description,
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
  if (t === 'photo_slideshow') {
    const out: Record<string, unknown> = { ...form };
    if (!Array.isArray(out.category_ids) || out.category_ids.length === 0) {
      delete out.category_ids;
    }
    if (out.aspect_ratio === 'any') {
      delete out.aspect_ratio;
    }
    for (const key of ['min_width', 'max_width', 'min_height', 'max_height'] as const) {
      if (out[key] === undefined || out[key] === null || out[key] === '') {
        delete out[key];
      }
    }
    return out;
  }
  if (t === 'qr_code') {
    const synced = syncQrOverlayFormData(form);
    const out: Record<string, unknown> = { ...synced };
    if (typeof out.title !== 'string' || !out.title.trim()) delete out.title;
    if (typeof out.description !== 'string' || !out.description.trim()) {
      delete out.description;
    }
    return out;
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

const UNSELECTED_OVERLAY_TYPE = '';

type OverlayDialogMode = 'create' | 'edit';

function OverlayDialog({
  open,
  mode,
  active,
  initial,
  existingOverlayIds,
  overlayTypes,
  onClose,
  onSaved,
}: {
  open: boolean;
  mode: OverlayDialogMode;
  active: SavedDisplay;
  initial: OverlayRow | null;
  existingOverlayIds: string[];
  overlayTypes: OverlayTypeSchemaMeta[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [saving, setSaving] = useState(false);
  const [localErr, setLocalErr] = useState<string | null>(null);
  const [label, setLabel] = useState('');
  const [description, setDescription] = useState('');
  const groupedTypes = useMemo(
    () => groupOverlayTypesByCategory(overlayTypes),
    [overlayTypes],
  );
  const [overlayType, setOverlayType] = useState(UNSELECTED_OVERLAY_TYPE);
  const [configForm, setConfigForm] = useState<Record<string, unknown>>({});
  const [categories, setCategories] = useState<ContentCategoryOption[]>([]);

  const exampleFor = useMemo(() => exampleForType(overlayTypes), [overlayTypes]);

  const previewId = useMemo(() => {
    if (mode !== 'create') return '';
    return overlayIdFromLabel(label, existingOverlayIds);
  }, [mode, label, existingOverlayIds]);

  const dialogTitle =
    mode === 'create'
      ? 'New overlay'
      : `Edit ${(initial?.label ?? '').trim() || initial?.id || 'overlay'}`;

  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    void (async () => {
      try {
        const res = await apiJson<{ items: ContentCategoryOption[] }>(
          active,
          '/v1/curator/categories',
        );
        if (!cancelled) {
          setCategories(
            (res.items ?? [])
              .filter((c) => typeof c.id === 'string' && c.id.trim())
              .map((c) => ({
                id: c.id.trim(),
                label: (c.label ?? c.id).trim() || c.id.trim(),
              })),
          );
        }
      } catch {
        if (!cancelled) setCategories([]);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [open, active]);

  useEffect(() => {
    if (!open) return;
    setLocalErr(null);
    if (initial) {
      setLabel(initial.label);
      setDescription(initial.description?.trim() ?? '');
      setOverlayType(initial.overlay_type);
      setConfigForm(
        overlayConfigForForm(initial.overlay_type, parseJsonObject(initial.config_json)),
      );
    } else {
      setLabel('');
      setDescription('');
      setOverlayType(UNSELECTED_OVERLAY_TYPE);
      setConfigForm({});
    }
  }, [open, initial]);

  const configSchema = useMemo(
    () =>
      overlayType
        ? prepareRjsfSchema(schemaForType(overlayTypes, overlayType))
        : null,
    [overlayTypes, overlayType],
  );

  const handleTypeChange = (next: string) => {
    setOverlayType(next);
    if (mode === 'create' && next) {
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
    if (!overlayType) {
      setLocalErr('Select an overlay type.');
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
      const body = {
        label: labelTrim,
        description: description.trim(),
        overlay_type: overlayType.trim(),
        config_json: configPayload,
      };
      if (mode === 'create') {
        await apiFetch(active, '/v1/display/overlays', {
          method: 'POST',
          body: JSON.stringify(body),
        });
      } else if (initial) {
        await apiFetch(active, `/v1/display/overlays/${encodeURIComponent(initial.id)}`, {
          method: 'PATCH',
          body: JSON.stringify(body),
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
      <DialogTitle>{dialogTitle}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {localErr && <Alert severity="error">{localErr}</Alert>}
          <TextField
            label="Label"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            required
            fullWidth
            autoFocus={mode === 'create'}
            disabled={saving}
            helperText={
              mode === 'create'
                ? previewId
                  ? `Id will be ${previewId} (derived from this label).`
                  : 'Id is derived from this label (letters and numbers).'
                : undefined
            }
          />
          <TextField
            label="Description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            fullWidth
            multiline
            minRows={2}
            disabled={saving}
          />
          <FormControl fullWidth disabled={saving || mode === 'edit'}>
            <InputLabel id="overlay-type-label">Overlay type</InputLabel>
            <Select
              labelId="overlay-type-label"
              label="Overlay type"
              value={overlayType}
              onChange={(e) => handleTypeChange(String(e.target.value))}
              displayEmpty
            >
              {mode === 'create' ? (
                <MenuItem value={UNSELECTED_OVERLAY_TYPE} disabled>
                  Select overlay type
                </MenuItem>
              ) : null}
              <ListSubheader>Effects</ListSubheader>
              {groupedTypes.effects.map((m) => (
                <MenuItem key={m.overlay_type} value={m.overlay_type}>
                  {overlayTypeLabel(m.overlay_type, m)}
                </MenuItem>
              ))}
              <ListSubheader>Widgets</ListSubheader>
              {groupedTypes.widgets.map((m) => (
                <MenuItem key={m.overlay_type} value={m.overlay_type}>
                  {overlayTypeLabel(m.overlay_type, m)}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          {mode === 'edit' ? (
            <Typography variant="caption" sx={{
              color: "text.secondary"
            }}>
              Overlay type cannot be changed after create. Delete and add a new overlay to switch
              types.
            </Typography>
          ) : null}
          {overlayType ? (
            <OverlayConfigPanel
              display={active}
              overlayType={overlayType}
              schema={configSchema}
              formData={configForm}
              onChange={setConfigForm}
              disabled={saving}
              categories={categories}
            />
          ) : null}
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

function OverlayTypeChips({
  row,
  overlayTypes,
}: {
  row: OverlayRow;
  overlayTypes: OverlayTypeSchemaMeta[];
}) {
  const meta = overlayTypeMetaFor(overlayTypes, row.overlay_type);
  const category = overlayTypeCategory(row.overlay_type, meta);
  return (
    <Stack direction="row" spacing={0.5} useFlexGap sx={{
      flexWrap: "wrap"
    }}>
      <Chip
        size="small"
        variant="outlined"
        label={overlayCategoryLabel(category)}
        sx={{ fontWeight: 500 }}
      />
      <Chip
        size="small"
        icon={<OverlayTypeIcon overlayType={row.overlay_type} />}
        label={overlayTypeLabel(row.overlay_type, meta)}
      />
    </Stack>
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
                <OverlayTypeChips row={row} overlayTypes={overlayTypes} />
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
          <Typography variant="subtitle1" sx={{
            fontWeight: 600
          }}>
            {row.label.trim() || row.id}
          </Typography>
          <OverlayTypeChips row={row} overlayTypes={overlayTypes} />
          <Typography variant="body2" sx={{
            color: "text.secondary"
          }}>
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

function OverlayCatalogSection({
  title,
  emptyHint,
  rows,
  layout,
  overlayTypes,
  canWrite,
  onEdit,
  onDelete,
}: {
  title: string;
  emptyHint: string;
  rows: OverlayRow[];
  layout: 'card' | 'table';
  overlayTypes: OverlayTypeSchemaMeta[];
  canWrite: boolean;
  onEdit: (row: OverlayRow) => void;
  onDelete: (id: string) => void;
}) {
  return (
    <Stack spacing={1.5}>
      <Typography variant="subtitle1" sx={{
        fontWeight: 600
      }}>
        {title}
      </Typography>
      {rows.length === 0 ? (
        <Typography variant="body2" sx={{
          color: "text.secondary"
        }}>
          {emptyHint}
        </Typography>
      ) : layout === 'card' ? (
        <Box sx={catalogCardGridSx}>
          {rows.map((row) => (
            <OverlayCard
              key={row.id}
              row={row}
              overlayTypes={overlayTypes}
              canWrite={canWrite}
              onEdit={() => onEdit(row)}
              onDelete={() => onDelete(row.id)}
            />
          ))}
        </Box>
      ) : (
        <OverlayTable
          rows={rows}
          overlayTypes={overlayTypes}
          canWrite={canWrite}
          onEdit={onEdit}
          onDelete={onDelete}
        />
      )}
    </Stack>
  );
}

export function OverlaysPage() {
  const { confirm, ConfirmDialogHost } = useConfirmDialog();
  const { active, displays } = useDisplay();
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
    return { rows: parsed, skipped: bad };
  }, [rawItems]);

  const overlayTypes = schemas?.overlay_types ?? [];

  const dataView = useClientDataView({
    items: rows,
    sortOptions: OVERLAY_SORT_OPTIONS,
    defaultSortId: 'label_asc',
    searchMatches: (row, q) => {
      const typeLabel = overlayTypeLabel(row.overlay_type);
      return (
        row.id.toLowerCase().includes(q) ||
        overlayRowTitle(row).toLowerCase().includes(q) ||
        row.overlay_type.toLowerCase().includes(q) ||
        typeLabel.toLowerCase().includes(q)
      );
    },
  });

  const displayRows = dataView.paginated.items;

  const { effects: effectRows, widgets: widgetRows } = useMemo(
    () => partitionOverlayRowsByCategory(displayRows, overlayTypes),
    [displayRows, overlayTypes],
  );

  const transferItems = useMemo(
    () =>
      dataView.allFilteredSorted.map((r) => ({
        id: r.id,
        label: overlayRowTitle(r),
      })),
    [dataView.allFilteredSorted],
  );

  const deleteRow = useCallback(
    async (id: string) => {
      if (!active) return;
      const row = rows.find((r) => r.id === id);
      const title = row?.label.trim() || id;
      const ok = await confirm({
        title: 'Delete overlay?',
        message: `Delete overlay “${title}”?`,
        confirmLabel: 'Delete',
        severity: 'error',
      });
      if (!ok) return;
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
    [active, confirm, load, rows],
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
        <Stack
          direction="row"
          spacing={0.25}
          sx={{
            alignItems: "center",
            mb: 0.5
          }}>
          <Typography variant="h6" sx={{
            fontWeight: 600
          }}>
            Overlays
          </Typography>
          <CatalogPageHelp title="Overlays">
            <OverlaysHelpContent />
          </CatalogPageHelp>
        </Stack>
        <Typography variant="body2" sx={{
          color: "text.secondary"
        }}>
          Overlays are <strong>Effects</strong> (full-screen motion and celebration layers, no
          viewport position) or <strong>Widgets</strong> (clocks, calendars, images, stock quotes,
          QR codes — placed on the display with position and scale). Attach overlays to curator
          programs on the Curators page; schedule when they run using curator schedule rules.
        </Typography>
      </Box>
      {(error || schemasError) && (
        <Alert severity="error">{error ?? schemasError}</Alert>
      )}
      {skipped > 0 && (
        <Alert severity="warning">
          Skipped {skipped} row(s) with missing or invalid data.
        </Alert>
      )}
      <CatalogListWithTransferSection
        toolbar={
          <DataViewToolbar
            layout={layout}
            onLayoutChange={setLayout}
            search={dataView.search}
            onSearchChange={dataView.setSearch}
            searchPlaceholder="Search overlays…"
            sortOptions={OVERLAY_SORT_OPTIONS}
            sortId={dataView.sortId}
            onSortChange={dataView.setSortId}
            onReload={() => void load()}
            reloadDisabled={loading}
            reloadAriaLabel="Reload overlays"
          >
            {canWrite && (
              <Button startIcon={<AddIcon />} variant="contained" onClick={openCreate}>
                Add overlay
              </Button>
            )}
          </DataViewToolbar>
        }
        list={
          <Stack spacing={2}>
            <DataViewEmptyState
              hasItems={rows.length > 0}
              hasFilteredMatches={displayRows.length > 0}
              emptyMessage="No overlays defined yet."
            />
            {displayRows.length > 0 ? (
            <Stack spacing={3}>
              <OverlayCatalogSection
                title="Effects"
                emptyHint="No effect overlays yet."
                rows={effectRows}
                layout={layout}
                overlayTypes={overlayTypes}
                canWrite={canWrite}
                onEdit={openEdit}
                onDelete={(id) => void deleteRow(id)}
              />
              <OverlayCatalogSection
                title="Widgets"
                emptyHint="No widget overlays yet."
                rows={widgetRows}
                layout={layout}
                overlayTypes={overlayTypes}
                canWrite={canWrite}
                onEdit={openEdit}
                onDelete={(id) => void deleteRow(id)}
              />
            </Stack>
            ) : null}
            <DataViewPagination
              count={dataView.filteredTotal}
              page={dataView.paginated.page}
              pageSize={dataView.paginated.pageSize}
              onPageChange={dataView.setPage}
              onPageSizeChange={dataView.setPageSize}
            />
          </Stack>
        }
        transferPanel={
          canWrite && displays.length > 1 ? (
            <CatalogDisplayTransferPanel
              kind="overlay"
              active={active}
              displays={displays}
              canWrite={canWrite}
              activeItems={transferItems}
              onTransferred={() => void load()}
            />
          ) : null
        }
      />
      {schemas && (
        <OverlayDialog
          open={dialogOpen}
          mode={dialogMode}
          active={active}
          initial={dialogInitial}
          existingOverlayIds={rows.map((r) => r.id)}
          overlayTypes={schemas.overlay_types}
          onClose={() => setDialogOpen(false)}
          onSaved={() => void load()}
        />
      )}
      <ConfirmDialogHost />
    </Stack>
  );
}
