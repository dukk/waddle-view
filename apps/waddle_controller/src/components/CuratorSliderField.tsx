import { Box, Slider, Stack, Typography } from '@mui/material';

type CuratorSliderFieldProps = {
  label: string;
  value: number;
  onChange: (value: number) => void;
  min: number;
  max: number;
  step: number;
  disabled?: boolean;
  formatValue?: (value: number) => string;
};

export function CuratorSliderField({
  label,
  value,
  onChange,
  min,
  max,
  step,
  disabled,
  formatValue,
}: CuratorSliderFieldProps) {
  const display = formatValue ? formatValue(value) : String(value);

  return (
    <Box>
      <Stack direction="row" justifyContent="space-between" alignItems="baseline" sx={{ mb: 0.5 }}>
        <Typography variant="body2" component="label">
          {label}
        </Typography>
        <Typography variant="body2" color="text.secondary" fontFamily="monospace">
          {display}
        </Typography>
      </Stack>
      <Slider
        value={value}
        onChange={(_, next) => onChange(Array.isArray(next) ? next[0]! : next)}
        min={min}
        max={max}
        step={step}
        disabled={disabled}
        valueLabelDisplay="off"
        size="small"
      />
    </Box>
  );
}
