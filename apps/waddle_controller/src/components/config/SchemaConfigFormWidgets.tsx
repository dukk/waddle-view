import type { WidgetProps } from '@rjsf/utils';
import { FormControlLabel, Stack, Switch, Typography } from '@mui/material';
import { CuratorSliderField } from '@/components/CuratorSliderField';

export function WaddleSwitchWidget(props: WidgetProps) {
  const { id, label, value, disabled, onChange, schema } = props;
  const checked = Boolean(value);
  return (
    <FormControlLabel
      control={
        <Switch
          id={id}
          checked={checked}
          disabled={disabled}
          onChange={(_, v) => onChange(v)}
        />
      }
      label={
        <Stack spacing={0.25}>
          <span>{label || schema.title || id}</span>
          {schema.description ? (
            <Typography variant="caption" color="text.secondary">
              {String(schema.description)}
            </Typography>
          ) : null}
        </Stack>
      }
    />
  );
}

export function WaddleSliderWidget(props: WidgetProps) {
  const { label, value, disabled, onChange, schema } = props;
  const min = typeof schema.minimum === 'number' ? schema.minimum : 0;
  const max = typeof schema.maximum === 'number' ? schema.maximum : 100;
  const step =
    schema.type === 'integer'
      ? 1
      : max - min <= 2
        ? 0.01
        : max - min <= 20
          ? 0.1
          : 1;
  const num = typeof value === 'number' && Number.isFinite(value) ? value : min;
  return (
    <CuratorSliderField
      label={label || (typeof schema.title === 'string' ? schema.title : 'Value')}
      value={num}
      onChange={(v) => onChange(v)}
      min={min}
      max={max}
      step={step}
      disabled={disabled}
      formatValue={(v) => (schema.type === 'integer' ? String(v) : v.toFixed(2))}
    />
  );
}
