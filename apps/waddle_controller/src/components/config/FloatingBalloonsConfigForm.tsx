import { Stack, Typography } from '@mui/material';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import { DurationInputField } from '@/components/DurationInputField';
import {
  FLOATING_BALLOONS_BALLOON_SCALE_MAX,
  FLOATING_BALLOONS_BALLOON_SCALE_MIN,
  FLOATING_BALLOONS_MAX_ACTIVE_MAX,
  FLOATING_BALLOONS_MAX_ACTIVE_MIN,
  FLOATING_BALLOONS_RISE_SPEED_PX_PER_SEC_MAX,
  FLOATING_BALLOONS_RISE_SPEED_PX_PER_SEC_MIN,
  FLOATING_BALLOONS_SCALE_JITTER_MAX,
  FLOATING_BALLOONS_SPAWN_INTERVAL_SEC_MAX,
  FLOATING_BALLOONS_SPAWN_INTERVAL_SEC_MIN,
} from '@/util/floatingBalloonsConfigSchema';
import { OverlayColorListField } from './OverlayColorListField';

function readNumber(form: Record<string, unknown>, key: string, fallback: number): number {
  const v = form[key];
  return typeof v === 'number' && Number.isFinite(v) ? v : fallback;
}

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

export function FloatingBalloonsConfigForm({ formData, onChange, disabled }: Props) {
  const patch = (partial: Record<string, unknown>) => onChange({ ...formData, ...partial });

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Configuration</Typography>
      <OverlayColorListField formData={formData} onChange={onChange} disabled={disabled} />
      <DurationInputField
        label="Spawn interval"
        valueSeconds={readNumber(formData, 'spawn_interval_sec', 22)}
        onChange={(spawn_interval_sec) =>
          patch({ spawn_interval_sec: Math.round(spawn_interval_sec) })
        }
        allowedUnits={['sec', 'min', 'hr']}
        minSeconds={FLOATING_BALLOONS_SPAWN_INTERVAL_SEC_MIN}
        maxSeconds={FLOATING_BALLOONS_SPAWN_INTERVAL_SEC_MAX}
        disabled={disabled}
      />
      <CuratorSliderField
        label="Rise speed (px/s)"
        value={readNumber(formData, 'rise_speed', 85)}
        onChange={(rise_speed) => patch({ rise_speed })}
        min={FLOATING_BALLOONS_RISE_SPEED_PX_PER_SEC_MIN}
        max={FLOATING_BALLOONS_RISE_SPEED_PX_PER_SEC_MAX}
        step={5}
        disabled={disabled}
        formatValue={(v) => String(Math.round(v))}
      />
      <CuratorSliderField
        label="Max on screen"
        value={readNumber(formData, 'max_active', 6)}
        onChange={(max_active) => patch({ max_active })}
        min={FLOATING_BALLOONS_MAX_ACTIVE_MIN}
        max={FLOATING_BALLOONS_MAX_ACTIVE_MAX}
        step={1}
        disabled={disabled}
        formatValue={(v) => String(Math.round(v))}
      />
      <CuratorSliderField
        label="Cluster chance"
        value={readNumber(formData, 'cluster_chance', 0.4)}
        onChange={(cluster_chance) => patch({ cluster_chance })}
        min={0}
        max={1}
        step={0.05}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Balloon scale"
        value={readNumber(formData, 'balloon_scale', 0.09)}
        onChange={(balloon_scale) => patch({ balloon_scale })}
        min={FLOATING_BALLOONS_BALLOON_SCALE_MIN}
        max={FLOATING_BALLOONS_BALLOON_SCALE_MAX}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Random size variation"
        value={readNumber(formData, 'scale_jitter', 0.25)}
        onChange={(scale_jitter) => patch({ scale_jitter })}
        min={0}
        max={FLOATING_BALLOONS_SCALE_JITTER_MAX}
        step={0.05}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Opacity"
        value={readNumber(formData, 'opacity', 0.92)}
        onChange={(opacity) => patch({ opacity })}
        min={0.2}
        max={1}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
    </Stack>
  );
}
