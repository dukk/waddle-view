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
import { CuratorSliderField } from '@/components/CuratorSliderField';
import { DurationInputField } from '@/components/DurationInputField';
import { ScreenConfigPanel } from '@/components/screens/ScreenConfigPanel';
import type { SavedDisplay } from '@/storage/displays';
import type { ScreenTypeSchemaMeta } from '@/storage/configSchemaCache';
import { screenIdFromLabel } from '@/util/catalogIdFromLabel';
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

const UNSELECTED_TYPE = '';
const DEFAULT_MIN_DWELL = 8;
const DEFAULT_MAX_DWELL = 15;
const DEFAULT_WEIGHT = 100;

type Props = {
  open: boolean;
  mode: ScreenDialogMode;
  active: SavedDisplay;
  initial: ScreenDialogRow | null;
  existingScreenIds: string[];
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
  existingScreenIds,
  screenTypes,
  schemaForType,
  exampleForType,
  onClose,
  onSaved,
}: Props) {
  const [saving, setSaving] = useState(false);
  const [localErr, setLocalErr] = useState<string | null>(null);
  const [label, setLabel] = useState('');
  const [description, setDescription] = useState('');
  const [screenType, setScreenType] = useState(UNSELECTED_TYPE);
  const [minDwell, setMinDwell] = useState(DEFAULT_MIN_DWELL);
  const [maxDwell, setMaxDwell] = useState(DEFAULT_MAX_DWELL);
  const [weight, setWeight] = useState(DEFAULT_WEIGHT);
  const [minGap, setMinGap] = useState(0);
  const [minPlacements, setMinPlacements] = useState(0);
  const [maxPlacements, setMaxPlacements] = useState(0);
  const [configForm, setConfigForm] = useState<Record<string, unknown>>({});
  const [categories, setCategories] = useState<ContentCategoryOption[]>([]);

  const previewId = useMemo(() => {
    if (mode !== 'create') return '';
    return screenIdFromLabel(label, existingScreenIds);
  }, [mode, label, existingScreenIds]);

  const configSchema = useMemo(
    () => (screenType ? prepareRjsfSchema(schemaForType(screenType)) : null),
    [schemaForType, screenType],
  );

  const dialogTitle =
    mode === 'create'
      ? 'Add screen'
      : `Edit ${(initial?.label ?? '').trim() || initial?.id || 'screen'}`;

  useEffect(() => {
    if (!open) return;
    setLocalErr(null);
    if (initial) {
      setLabel(initial.label ?? '');
      setDescription(initial.description?.trim() ?? '');
      setScreenType(initial.screen_type);
      setMinDwell(initial.min_dwell_seconds);
      setMaxDwell(initial.max_dwell_seconds);
      setWeight(initial.frequency_weight);
      setMinGap(initial.min_gap_between_shows_seconds);
      setMinPlacements(initial.min_placements_per_program);
      setMaxPlacements(initial.max_placements_per_program ?? 0);
      setConfigForm(parseJsonObject(initial.config_json));
    } else {
      setLabel('');
      setDescription('');
      setScreenType(UNSELECTED_TYPE);
      setMinDwell(DEFAULT_MIN_DWELL);
      setMaxDwell(DEFAULT_MAX_DWELL);
      setWeight(DEFAULT_WEIGHT);
      setMinGap(0);
      setMinPlacements(0);
      setMaxPlacements(0);
      setConfigForm({});
    }
  }, [open, initial]);

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
    if (mode === 'create' && next) {
      setConfigForm(exampleForType(next));
    }
  };

  const submit = async () => {
    setLocalErr(null);
    const labelTrim = label.trim();
    if (!labelTrim) {
      setLocalErr('Label is required.');
      return;
    }
    if (!screenType) {
      setLocalErr('Select a screen type.');
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
            label: labelTrim,
            description: description.trim(),
            screen_type: screenType.trim(),
            min_dwell_seconds: minDwell,
            max_dwell_seconds: maxDwell,
            frequency_weight: weight,
            min_gap_between_shows_seconds: minGap,
            min_placements_per_program: minPlacements,
            max_placements_per_program: maxPlacements <= 0 ? null : maxPlacements,
            config_json: configForm,
          }),
        });
      } else if (initial) {
        await apiFetch(active, `/v1/screens/${encodeURIComponent(initial.id)}`, {
          method: 'PATCH',
          body: JSON.stringify({
            label: labelTrim,
            description: description.trim(),
            min_dwell_seconds: minDwell,
            max_dwell_seconds: maxDwell,
            frequency_weight: weight,
            min_gap_between_shows_seconds: minGap,
            min_placements_per_program: minPlacements,
            max_placements_per_program: maxPlacements <= 0 ? null : maxPlacements,
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
            <InputLabel id="screen-type-label">Screen type</InputLabel>
            <Select
              labelId="screen-type-label"
              label="Screen type"
              value={screenType}
              onChange={(e) => handleTypeChange(String(e.target.value))}
              displayEmpty
            >
              {mode === 'create' ? (
                <MenuItem value={UNSELECTED_TYPE} disabled>
                  Select screen type
                </MenuItem>
              ) : null}
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
          {screenType ? (
            <>
              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
                <DurationInputField
                  label="Min dwell"
                  valueSeconds={minDwell}
                  onChange={setMinDwell}
                  allowedUnits={['sec', 'min', 'hr']}
                  minSeconds={1}
                  maxSeconds={86400}
                  disabled={saving}
                />
                <DurationInputField
                  label="Max dwell"
                  valueSeconds={maxDwell}
                  onChange={setMaxDwell}
                  allowedUnits={['sec', 'min', 'hr']}
                  minSeconds={1}
                  maxSeconds={86400}
                  disabled={saving}
                />
              </Stack>
              <CuratorSliderField
                label="Frequency weight"
                value={weight}
                onChange={setWeight}
                min={0}
                max={500}
                step={5}
                disabled={saving}
                formatValue={(v) => String(v)}
              />
              <Typography variant="caption" color="text.secondary" sx={{ mt: -1 }}>
                Higher values are chosen more often; recent appearances in the history window reduce
                effective weight.
              </Typography>
              <DurationInputField
                label="Min gap between shows"
                valueSeconds={minGap}
                onChange={setMinGap}
                allowedUnits={['sec', 'min', 'hr', 'day']}
                minSeconds={0}
                maxSeconds={604800}
                disabled={saving}
                helperText="Minimum time since the last showing before this screen is eligible again."
              />
              <CuratorSliderField
                label="Min placements per program"
                value={minPlacements}
                onChange={setMinPlacements}
                min={0}
                max={20}
                step={1}
                disabled={saving}
              />
              <CuratorSliderField
                label="Max placements per program"
                value={maxPlacements}
                onChange={setMaxPlacements}
                min={0}
                max={20}
                step={1}
                disabled={saving}
                formatValue={(v) => (v <= 0 ? 'No cap' : String(v))}
              />
              <ScreenConfigPanel
                display={active}
                schema={configSchema}
                formData={configForm}
                onChange={setConfigForm}
                disabled={saving}
                categories={categories}
              />
            </>
          ) : null}
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
