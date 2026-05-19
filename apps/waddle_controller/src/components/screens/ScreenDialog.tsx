import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
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
  TextField,
  Typography,
} from '@mui/material';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import type { ContentCategoryOption } from '@/components/config/ContentCategorySelectField';
import { ScreenConfigPanel } from '@/components/screens/ScreenConfigPanel';
import type { SavedDisplay } from '@/storage/displays';
import type { ScreenTypeSchemaMeta } from '@/storage/configSchemaCache';
import { completeDialogSave } from '@/util/dialogSave';
import { parseJsonObject } from '@/util/json';
import { prepareRjsfSchema, validateConfigAgainstSchema } from '@/util/rjsfSchema';
import { screenTypeLabel } from '@/util/screenTypeLabel';

export type ScreenDialogRow = {
  id: string;
  label?: string | null;
  description?: string;
  screen_type: string;
  config_json: string;
  min_dwell_seconds: number;
  max_dwell_seconds: number;
  frequency_weight: number;
  min_gap_between_shows_seconds: number;
  min_placements_per_program: number;
  max_placements_per_program?: number | null;
};

export type ScreenDialogMode = 'create' | 'edit';

const DEFAULT_MIN_DWELL = 8;
const DEFAULT_MAX_DWELL = 15;
const DEFAULT_WEIGHT = 100;

type Props = {
  open: boolean;
  mode: ScreenDialogMode;
  active: SavedDisplay;
  initial: ScreenDialogRow | null;
  screenTypes: ScreenTypeSchemaMeta[];
  schemaForType: (screenType: string) => unknown;
  exampleForType: (screenType: string) => Record<string, unknown>;
  onClose: () => void;
  onSaved: () => void | Promise<void>;
};

export function ScreenDialog({
  open,
  mode,
  active,
  initial,
  screenTypes,
  schemaForType,
  exampleForType,
  onClose,
  onSaved,
}: Props) {
  const [saving, setSaving] = useState(false);
  const [localErr, setLocalErr] = useState<string | null>(null);
  const [id, setId] = useState('');
  const [label, setLabel] = useState('');
  const [description, setDescription] = useState('');
  const [screenType, setScreenType] = useState(screenTypes[0]?.screen_type ?? '');
  const [minDwell, setMinDwell] = useState(DEFAULT_MIN_DWELL);
  const [maxDwell, setMaxDwell] = useState(DEFAULT_MAX_DWELL);
  const [weight, setWeight] = useState(DEFAULT_WEIGHT);
  const [minGap, setMinGap] = useState(0);
  const [minPlacements, setMinPlacements] = useState(0);
  const [maxPlacements, setMaxPlacements] = useState<number | ''>('');
  const [configForm, setConfigForm] = useState<Record<string, unknown>>({});
  const [categories, setCategories] = useState<ContentCategoryOption[]>([]);

  const configSchema = useMemo(
    () => prepareRjsfSchema(schemaForType(screenType)),
    [schemaForType, screenType],
  );

  useEffect(() => {
    if (!open) return;
    setLocalErr(null);
    if (initial) {
      setId(initial.id);
      setLabel(initial.label ?? '');
      setDescription(initial.description?.trim() ?? '');
      setScreenType(initial.screen_type);
      setMinDwell(initial.min_dwell_seconds);
      setMaxDwell(initial.max_dwell_seconds);
      setWeight(initial.frequency_weight);
      setMinGap(initial.min_gap_between_shows_seconds);
      setMinPlacements(initial.min_placements_per_program);
      setMaxPlacements(initial.max_placements_per_program ?? '');
      setConfigForm(parseJsonObject(initial.config_json));
    } else {
      const defaultType = screenTypes[0]?.screen_type ?? '';
      setId('');
      setLabel('');
      setDescription('');
      setScreenType(defaultType);
      setMinDwell(DEFAULT_MIN_DWELL);
      setMaxDwell(DEFAULT_MAX_DWELL);
      setWeight(DEFAULT_WEIGHT);
      setMinGap(0);
      setMinPlacements(0);
      setMaxPlacements('');
      setConfigForm(exampleForType(defaultType));
    }
  }, [open, initial, screenTypes, exampleForType]);

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

  const handleTypeChange = (next: string) => {
    setScreenType(next);
    if (mode === 'create') {
      setConfigForm(exampleForType(next));
    }
  };

  const submit = async () => {
    setLocalErr(null);
    const idTrim = id.trim();
    if (mode === 'create' && !idTrim) {
      setLocalErr('Screen id is required.');
      return;
    }
    if (minDwell <= 0 || maxDwell <= 0 || minDwell > maxDwell) {
      setLocalErr('Min dwell must be positive and not greater than max dwell.');
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
        await apiFetch(active, '/v1/screens', {
          method: 'POST',
          body: JSON.stringify({
            id: idTrim,
            screen_type: screenType.trim(),
            label: label.trim() || undefined,
            description: description.trim(),
            min_dwell_seconds: minDwell,
            max_dwell_seconds: maxDwell,
            frequency_weight: weight,
            min_gap_between_shows_seconds: minGap,
            min_placements_per_program: minPlacements,
            max_placements_per_program: maxPlacements === '' ? null : Number(maxPlacements),
            config_json: configForm,
          }),
        });
      } else if (initial) {
        await apiFetch(active, `/v1/screens/${encodeURIComponent(initial.id)}`, {
          method: 'PATCH',
          body: JSON.stringify({
            label: label.trim(),
            description: description.trim(),
            min_dwell_seconds: minDwell,
            max_dwell_seconds: maxDwell,
            frequency_weight: weight,
            min_gap_between_shows_seconds: minGap,
            min_placements_per_program: minPlacements,
            max_placements_per_program: maxPlacements === '' ? null : Number(maxPlacements),
            config_json: configForm,
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
      <DialogTitle>
        {mode === 'create' ? 'Add screen' : `Edit ${initial?.id ?? 'screen'}`}
      </DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {localErr && <Alert severity="error">{localErr}</Alert>}
          {mode === 'create' ? (
            <TextField
              label="Screen id"
              value={id}
              onChange={(e) => setId(e.target.value)}
              required
              fullWidth
              autoFocus
            />
          ) : (
            <TextField label="Screen id" value={id} disabled fullWidth />
          )}
          <TextField
            label="Label"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            fullWidth
            helperText={mode === 'create' ? 'Optional; defaults to screen id when empty.' : undefined}
          />
          <TextField
            label="Description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            fullWidth
            multiline
            minRows={2}
          />
          <FormControl fullWidth>
            <InputLabel id="screen-type-label">Screen type</InputLabel>
            <Select
              labelId="screen-type-label"
              label="Screen type"
              value={screenType}
              onChange={(e) => handleTypeChange(String(e.target.value))}
              disabled={mode === 'edit'}
            >
              {screenTypes.map((m) => (
                <MenuItem key={m.screen_type} value={m.screen_type}>
                  {screenTypeLabel(m.screen_type, m)}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          {mode === 'edit' ? (
            <Typography variant="caption" color="text.secondary">
              Screen type cannot be changed after create. Delete and add a new screen to switch
              types.
            </Typography>
          ) : null}
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
          <ScreenConfigPanel
            display={active}
            schema={configSchema}
            formData={configForm}
            onChange={setConfigForm}
            disabled={saving}
            categories={categories}
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={() => void submit()} disabled={saving}>
          {saving ? 'Saving…' : mode === 'create' ? 'Create' : 'Save'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
