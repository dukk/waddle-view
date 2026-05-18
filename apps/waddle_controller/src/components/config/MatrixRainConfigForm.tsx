import { Stack, Typography } from '@mui/material';
import { CuratorSliderField } from '@/components/CuratorSliderField';

function readNumber(form: Record<string, unknown>, key: string, fallback: number): number {
  const v = form[key];
  return typeof v === 'number' && Number.isFinite(v) ? v : fallback;
}

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

export function MatrixRainConfigForm({ formData, onChange, disabled }: Props) {
  const patch = (partial: Record<string, unknown>) => onChange({ ...formData, ...partial });

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Configuration</Typography>
      <CuratorSliderField
        label="Opacity"
        value={readNumber(formData, 'opacity', 0.35)}
        onChange={(opacity) => patch({ opacity })}
        min={0.08}
        max={0.85}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Fall speed"
        value={readNumber(formData, 'fall_speed', 0.45)}
        onChange={(fall_speed) => patch({ fall_speed })}
        min={0.05}
        max={2}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
    </Stack>
  );
}
