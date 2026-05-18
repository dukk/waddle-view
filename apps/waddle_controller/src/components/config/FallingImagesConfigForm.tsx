import { Stack, Typography } from '@mui/material';
import type { FieldProps } from '@rjsf/utils';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import type { SavedDisplay } from '@/storage/displays';
import { OverlayBlobKeysField } from './OverlayBlobKeysField';

function readNumber(form: Record<string, unknown>, key: string, fallback: number): number {
  const v = form[key];
  return typeof v === 'number' && Number.isFinite(v) ? v : fallback;
}

function readKeys(form: Record<string, unknown>): string[] {
  const raw = form.image_blob_keys;
  if (!Array.isArray(raw)) return [];
  return raw.filter((v): v is string => typeof v === 'string' && v.trim().length > 0);
}

type Props = {
  display: SavedDisplay;
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

export function FallingImagesConfigForm({ display, formData, onChange, disabled }: Props) {
  const patch = (partial: Record<string, unknown>) => onChange({ ...formData, ...partial });

  const blobFieldProps = {
    display,
    formData: readKeys(formData),
    onChange: (keys: string[]) => patch({ image_blob_keys: keys }),
    schema: { title: 'Images' },
    disabled,
    rawErrors: [],
    idSchema: { $id: 'image_blob_keys' },
    name: 'image_blob_keys',
  } as FieldProps;

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Configuration</Typography>
      <OverlayBlobKeysField {...blobFieldProps} />
      <CuratorSliderField
        label="Drop interval"
        value={readNumber(formData, 'drop_interval_sec', 45)}
        onChange={(drop_interval_sec) => patch({ drop_interval_sec: Math.round(drop_interval_sec) })}
        min={15}
        max={180}
        step={1}
        disabled={disabled}
        formatValue={(v) => `${Math.round(v)}s`}
      />
      <CuratorSliderField
        label="Fall speed"
        value={readNumber(formData, 'fall_speed', 0.12)}
        onChange={(fall_speed) => patch({ fall_speed })}
        min={0.05}
        max={1}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Image scale"
        value={readNumber(formData, 'image_scale', 0.12)}
        onChange={(image_scale) => patch({ image_scale })}
        min={0.04}
        max={0.35}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Random size variation"
        value={readNumber(formData, 'scale_jitter', 0.33)}
        onChange={(scale_jitter) => patch({ scale_jitter })}
        min={0}
        max={1}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => (v <= 0 ? 'Off' : v.toFixed(2))}
      />
    </Stack>
  );
}
