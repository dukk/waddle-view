import { Stack, TextField, Typography } from '@mui/material';
import { CuratorSliderField } from '@/components/CuratorSliderField';

const DEFAULT_COLOR = '#FF3B30';

function readNumber(form: Record<string, unknown>, key: string, fallback: number): number {
  const v = form[key];
  return typeof v === 'number' && Number.isFinite(v) ? v : fallback;
}

function readColor(form: Record<string, unknown>): string {
  const v = form.color;
  if (typeof v !== 'string') {
    return DEFAULT_COLOR;
  }
  const trimmed = v.trim();
  return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(trimmed) ? trimmed : DEFAULT_COLOR;
}

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

export function EdgeGlowConfigForm({ formData, onChange, disabled }: Props) {
  const patch = (partial: Record<string, unknown>) => onChange({ ...formData, ...partial });
  const color = readColor(formData);

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Configuration</Typography>
      <Stack direction="row" spacing={2} sx={{
        alignItems: "center"
      }}>
        <TextField
          label="Glow color"
          type="color"
          value={color.length === 9 ? color.slice(0, 7) : color}
          onChange={(e) => patch({ color: e.target.value })}
          disabled={disabled}
          slotProps={{ input: { sx: { width: 56, height: 40, p: 0.5 } } }}
        />
        <TextField
          label="Hex"
          value={color}
          onChange={(e) => patch({ color: e.target.value.trim() })}
          disabled={disabled}
          size="small"
          sx={{ flex: 1 }}
          placeholder={DEFAULT_COLOR}
        />
      </Stack>
      <CuratorSliderField
        label="Intensity"
        value={readNumber(formData, 'intensity', 0.65)}
        onChange={(intensity) => patch({ intensity })}
        min={0.08}
        max={0.95}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Pulse speed"
        value={readNumber(formData, 'pulse_speed', 1)}
        onChange={(pulse_speed) => patch({ pulse_speed })}
        min={0.05}
        max={3}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
    </Stack>
  );
}
