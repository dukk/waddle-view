import { Stack, Typography } from '@mui/material';
import type { FieldProps } from '@rjsf/utils';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import type { SavedDisplay } from '@/storage/displays';
import {
  FALLING_IMAGES_DROP_INTERVAL_SEC_MAX,
  FALLING_IMAGES_DROP_INTERVAL_SEC_MIN,
  FALLING_IMAGES_FALL_SPEED_PX_PER_SEC_DEFAULT,
  FALLING_IMAGES_FALL_SPEED_PX_PER_SEC_MAX,
  FALLING_IMAGES_FALL_SPEED_PX_PER_SEC_MIN,
  FALLING_IMAGES_IMAGE_SCALE_MAX,
  FALLING_IMAGES_IMAGE_SCALE_MIN,
} from '@/util/fallingImagesConfigSchema';
import { OverlayBlobKeysField } from './OverlayBlobKeysField';

const IMAGE_SCALE_MIN_PCT = FALLING_IMAGES_IMAGE_SCALE_MIN * 100;
const IMAGE_SCALE_MAX_PCT = FALLING_IMAGES_IMAGE_SCALE_MAX * 100;

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
  } as unknown as FieldProps;

  const imageScale = readNumber(formData, 'image_scale', 0.12);
  const scaleJitter = readNumber(formData, 'scale_jitter', 0.33);

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Configuration</Typography>
      <OverlayBlobKeysField display={display} {...blobFieldProps} />
      <CuratorSliderField
        label="Drop interval"
        value={readNumber(formData, 'drop_interval_sec', 45)}
        onChange={(drop_interval_sec) => patch({ drop_interval_sec: Math.round(drop_interval_sec) })}
        min={FALLING_IMAGES_DROP_INTERVAL_SEC_MIN}
        max={FALLING_IMAGES_DROP_INTERVAL_SEC_MAX}
        step={1}
        disabled={disabled}
        formatValue={(v) => `${Math.round(v)}s`}
      />
      <CuratorSliderField
        label="Fall speed"
        value={readNumber(formData, 'fall_speed', FALLING_IMAGES_FALL_SPEED_PX_PER_SEC_DEFAULT)}
        onChange={(fall_speed) => patch({ fall_speed: Math.round(fall_speed) })}
        min={FALLING_IMAGES_FALL_SPEED_PX_PER_SEC_MIN}
        max={FALLING_IMAGES_FALL_SPEED_PX_PER_SEC_MAX}
        step={5}
        disabled={disabled}
        formatValue={(v) => `${Math.round(v)} px/s`}
      />
      <CuratorSliderField
        label="Image scale"
        value={imageScale * 100}
        onChange={(pct) => patch({ image_scale: pct / 100 })}
        min={IMAGE_SCALE_MIN_PCT}
        max={IMAGE_SCALE_MAX_PCT}
        step={1}
        disabled={disabled}
        formatValue={(v) => `${Math.round(v)}%`}
      />
      <CuratorSliderField
        label="Random size variation"
        value={scaleJitter * 100}
        onChange={(pct) => patch({ scale_jitter: pct / 100 })}
        min={0}
        max={100}
        step={1}
        disabled={disabled}
        formatValue={(v) => (v <= 0 ? 'Off' : `${Math.round(v)}%`)}
      />
    </Stack>
  );
}
