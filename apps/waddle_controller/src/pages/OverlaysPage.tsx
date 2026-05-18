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
import { SchemaConfigForm } from '@/components/config/SchemaConfigForm';
import { parseJsonObject } from '@/util/json';
import { prepareRjsfSchema } from '@/util/rjsfSchema';
import { validateConfigAgainstSchema } from '@/util/rjsfSchema';
import type { SavedDisplay } from '@/storage/displays';

type OverlayRow = {
  id: string;
  overlay_type: string;
  name: string;
  config_json: unknown;
  config_json_schema?: unknown;
  example_config_json?: unknown;
};

type OverlayTypeMeta = {
  overlay_type: string;
  config_json_schema: unknown;
  example_config_json: unknown;
};

const OVERLAY_TYPE_LABELS: Record<string, string> = {
  hearts_rain: 'Hearts rain',
  birthday_confetti: 'Birthday confetti',
  bouncing_message: 'Bouncing message',
  falling_images: 'Falling images',
};

function overlayTypeLabel(t: string): string {
  return OVERLAY_TYPE_LABELS[t] ?? t.replace(/_/g, ' ');
}

function sortByName(a: OverlayRow, b: OverlayRow): number {
  const an = a.name.trim() || a.id;
  const bn = b.name.trim() || b.id;
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
  const name =
    typeof raw.name === 'string'
      ? raw.name
      : typeof raw.label === 'string'
        ? raw.label
        : '';
  return {
    id,
    overlay_type: overlayType,
    name,
    config_json: raw.config_json,
    config_json_schema: raw.config_json_schema,
    example_config_json: raw.example_config_json,
  };
}

function exampleForType(meta: OverlayTypeMeta[]): (type: string) => Record<string, unknown> {
  return (type: string) => {
    const hit = meta.find((m) => m.overlay_type === type);
    return parseJsonObject(hit?.example_config_json);
  };
}

function schemaForType(meta: OverlayTypeMeta[], type: string): unknown {
  const hit = meta.find((m) => m.overlay_type === type);
  return hit?.config_json_schema ?? { type: 'object', additionalProperties: true };
}

function configPreview(row: OverlayRow): string {
  const cfg = parseJsonObject(row.config_json);
  const messages = cfg.messages;
  if (Array.isArray(messages) && messages.length > 0) {
    const first = messages.find((m) => typeof m === 'string' && m.trim());
    if (typeof first === 'string') return first.trim();
  }
  const keys = Object.keys(cfg).filter((k) => k !== 'messages');
  if (keys.length === 0) return '—';
  return keys.slice(0, 3).join(', ');
}

type OverlayDialogMode = 'create' | 'edit';

function OverlayDialog({
  open,
  mode,
  active,
  initial,
  meta,
  onClose,
  onSaved,
}: {
  open: boolean;
  mode: OverlayDialogMode;
  active: SavedDisplay;
  initial: OverlayRow | null;
  meta: OverlayTypeMeta[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [saving, setSaving] = useState(false);
  const [localErr, setLocalErr] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [overlayType, setOverlayType] = useState(meta[0]?.overlay_type ?? 'hearts_rain');
  const [configForm, setConfigForm] = useState<Record<string, unknown>>({});

  const exampleFor = useMemo(() => exampleForType(meta), [meta]);

  useEffect(() => {
    if (!open) return;
    setLocalErr(null);
    if (initial) {
      setName(initial.name);
      setOverlayType(initial.overlay_type);
      setConfigForm(parseJsonObject(initial.config_json));
    } else {
      setName('');
      setOverlayType(meta[0]?.overlay_type ?? 'hearts_rain');
      setConfigForm(exampleFor(meta[0]?.overlay_type ?? 'hearts_rain'));
    }
  }, [open, initial, meta, exampleFor]);

  const configSchema = useMemo(
    () => prepareRjsfSchema(schemaForType(meta, overlayType)),
    [meta, overlayType],
  );

  const handleTypeChange = (next: string) => {
    setOverlayType(next);
    if (mode === 'create') {
      setConfigForm(exampleFor(next));
    }
  };

  const submit = async () => {
    setLocalErr(null);
    const nameTrim = name.trim();
    if (!nameTrim) {
      setLocalErr('Name is required.');
      return;
    }
    const validationErrors = validateConfigAgainstSchema(configForm, configSchema);
    if (validationErrors.length > 0) {
      setLocalErr(validationErrors[0] ?? 'Invalid configuration.');
      return;
    }
    setSaving(true);
    try {
      if (mode === 'create') {
        await apiFetch(active, '/v1/display/overlays', {
          method: 'POST',
          body: JSON.stringify({
            name: nameTrim,
            overlay_type: overlayType.trim(),
            config_json: configForm,
          }),
        });
      } else if (initial) {
        await apiFetch(active, `/v1/display/overlays/${encodeURIComponent(initial.id)}`, {
          method: 'PATCH',
          body: JSON.stringify({
            name: nameTrim,
            overlay_type: overlayType.trim(),
            config_json: configForm,
          }),
        });
      }
      onSaved();
      onClose();
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
            label="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
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
              {meta.map((m) => (
                <MenuItem key={m.overlay_type} value={m.overlay_type}>
                  {overlayTypeLabel(m.overlay_type)}
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
          <SchemaConfigForm
            display={active}
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
  canWrite,
  onEdit,
  onDelete,
}: {
  rows: OverlayRow[];
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
              <TableCell sx={{ fontWeight: 600 }}>{row.name.trim() || row.id}</TableCell>
              <TableCell>
                <Chip size="small" label={overlayTypeLabel(row.overlay_type)} />
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
  canWrite,
  onEdit,
  onDelete,
}: {
  row: OverlayRow;
  canWrite: boolean;
  onEdit: () => void;
  onDelete: () => void;
}) {
  return (
    <Card variant="outlined">
      <CardContent>
        <Typography variant="subtitle1" fontWeight={600}>
          {row.name.trim() || row.id}
        </Typography>
        <Chip size="small" label={overlayTypeLabel(row.overlay_type)} sx={{ mt: 1 }} />
        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
          {configPreview(row)}
        </Typography>
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
  const [meta, setMeta] = useState<OverlayTypeMeta[]>([]);
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
        const [overlaysRes, metaRes] = await Promise.all([
          apiJson<{ items: Record<string, unknown>[] }>(active, '/v1/display/overlays'),
          apiJson<{ items: OverlayTypeMeta[] }>(active, '/v1/meta/overlay-types'),
        ]);
        setRawItems(overlaysRes.items ?? []);
        setMeta(metaRes.items ?? []);
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
    parsed.sort(sortByName);
    return { rows: parsed, skipped: bad };
  }, [rawItems]);

  const deleteRow = useCallback(
    async (id: string) => {
      if (!active) return;
      const row = rows.find((r) => r.id === id);
      const title = row?.name.trim() || id;
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

      {error && <Alert severity="error">{error}</Alert>}
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
              canWrite={canWrite}
              onEdit={() => openEdit(row)}
              onDelete={() => void deleteRow(row.id)}
            />
          ))}
        </Box>
      ) : (
        <OverlayTable
          rows={rows}
          canWrite={canWrite}
          onEdit={openEdit}
          onDelete={(id) => void deleteRow(id)}
        />
      )}

      <OverlayDialog
        open={dialogOpen}
        mode={dialogMode}
        active={active}
        initial={dialogInitial}
        meta={meta}
        onClose={() => setDialogOpen(false)}
        onSaved={() => void load()}
      />
    </Stack>
  );
}
