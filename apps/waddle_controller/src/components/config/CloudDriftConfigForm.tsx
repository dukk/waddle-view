import {
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { CuratorSliderField } from '@/components/CuratorSliderField';

const DEFAULT_COLOR = '#C8CDD3';

const CLOUD_TYPE_OPTIONS: { value: string; label: string }[] = [
  { value: 'cirrostratus', label: 'Cirrostratus' },
  { value: 'cirrus', label: 'Cirrus' },
  { value: 'cumulus', label: 'Cumulus' },
  { value: 'stratocumulus', label: 'Stratocumulus' },
  { value: 'altostratus', label: 'Altostratus' },
];

function readNumber(form: Record<string, unknown>, key: string, fallback: number): number {
  const v = form[key];
  return typeof v === 'number' && Number.isFinite(v) ? v : fallback;
}

function readCloudType(form: Record<string, unknown>): string {
  const v = form.cloud_type;
  if (typeof v !== 'string') {
    return 'cirrostratus';
  }
  const trimmed = v.trim();
  return CLOUD_TYPE_OPTIONS.some((o) => o.value === trimmed) ? trimmed : 'cirrostratus';
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

export function CloudDriftConfigForm({ formData, onChange, disabled }: Props) {
  const patch = (partial: Record<string, unknown>) => onChange({ ...formData, ...partial });
  const color = readColor(formData);

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Configuration</Typography>
      <FormControl fullWidth size="small" disabled={disabled}>
        <InputLabel id="cloud-drift-type-label">Cloud type</InputLabel>
        <Select
          labelId="cloud-drift-type-label"
          label="Cloud type"
          value={readCloudType(formData)}
          onChange={(e) => patch({ cloud_type: e.target.value })}
        >
          {CLOUD_TYPE_OPTIONS.map((opt) => (
            <MenuItem key={opt.value} value={opt.value}>
              {opt.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <Stack direction="row" spacing={2} sx={{
        alignItems: "center"
      }}>
        <TextField
          label="Cloud color"
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
        label="Scatter"
        value={readNumber(formData, 'scatter', 0.45)}
        onChange={(scatter) => patch({ scatter })}
        min={0}
        max={1}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Density"
        value={readNumber(formData, 'density', 0.35)}
        onChange={(density) => patch({ density })}
        min={0.1}
        max={0.9}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Transparency"
        value={readNumber(formData, 'opacity', 0.42)}
        onChange={(opacity) => patch({ opacity })}
        min={0.08}
        max={0.85}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
    </Stack>
  );
}
