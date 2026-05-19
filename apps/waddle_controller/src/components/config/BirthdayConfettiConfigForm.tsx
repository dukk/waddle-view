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

export function BirthdayConfettiConfigForm({ formData, onChange, disabled }: Props) {
  const patch = (partial: Record<string, unknown>) => onChange({ ...formData, ...partial });

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Configuration</Typography>
      <Typography variant="body2" color="text.secondary">
        Thin rectangular confetti strips in red, yellow, cyan, and magenta unless custom colors
        are set in config JSON.
      </Typography>
      <CuratorSliderField
        label="Density"
        value={readNumber(formData, 'density', 0.36)}
        onChange={(density) => patch({ density })}
        min={0.15}
        max={0.9}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Fall speed"
        value={readNumber(formData, 'fall_speed', 0.14)}
        onChange={(fall_speed) => patch({ fall_speed })}
        min={0.02}
        max={1.8}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Opacity"
        value={readNumber(formData, 'opacity', 0.46)}
        onChange={(opacity) => patch({ opacity })}
        min={0.12}
        max={0.72}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
    </Stack>
  );
}
