import type { WidgetProps } from '@rjsf/utils';
import {
  FormControl,
  FormHelperText,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Switch,
  Typography,
} from '@mui/material';
import { readEnumLabelsFromSchema } from '@/constants/clockEnumLabels';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import { DurationInputField } from '@/components/DurationInputField';
import type { DurationUnit } from '@/util/durationInput';

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

function parseDurationUnits(schema: WidgetProps['schema']): DurationUnit[] {
  const raw = schema['x-waddle-duration-units'];
  if (!Array.isArray(raw)) {
    return ['sec', 'min', 'hr'];
  }
  const allowed: DurationUnit[] = [];
  for (const u of raw) {
    if (u === 'sec' || u === 'min' || u === 'hr' || u === 'day') {
      allowed.push(u);
    }
  }
  return allowed.length > 0 ? allowed : ['sec', 'min', 'hr'];
}

export function WaddleDurationWidget(props: WidgetProps) {
  const { label, value, disabled, onChange, schema } = props;
  const num = typeof value === 'number' && Number.isFinite(value) ? value : 0;
  const minSeconds =
    typeof schema.minimum === 'number' ? Math.round(schema.minimum) : undefined;
  const maxSeconds =
    typeof schema.maximum === 'number' ? Math.round(schema.maximum) : undefined;
  return (
    <DurationInputField
      label={label || (typeof schema.title === 'string' ? schema.title : 'Duration')}
      valueSeconds={num}
      onChange={(v) => onChange(v)}
      allowedUnits={parseDurationUnits(schema)}
      minSeconds={minSeconds}
      maxSeconds={maxSeconds}
      disabled={disabled}
      helperText={
        typeof schema.description === 'string' ? schema.description : undefined
      }
    />
  );
}

export function WaddleEnumSelectWidget(props: WidgetProps) {
  const { id, label, value, disabled, onChange, schema, rawErrors } = props;
  const labels = readEnumLabelsFromSchema(schema as Record<string, unknown>);
  const enumValues = Array.isArray(schema.enum)
    ? schema.enum.filter((v): v is string => typeof v === 'string')
    : [];
  const current = typeof value === 'string' ? value : enumValues[0] ?? '';

  return (
    <FormControl fullWidth error={rawErrors != null && rawErrors.length > 0} disabled={disabled}>
      <InputLabel id={`${id}-label`}>{label || schema.title || id}</InputLabel>
      <Select
        labelId={`${id}-label`}
        label={label || schema.title || id}
        value={current}
        onChange={(e) => onChange(e.target.value)}
      >
        {enumValues.map((v) => (
          <MenuItem key={v} value={v}>
            {labels?.[v] ?? v}
          </MenuItem>
        ))}
      </Select>
      {rawErrors?.length ? (
        <FormHelperText>{rawErrors.join(', ')}</FormHelperText>
      ) : schema.description ? (
        <FormHelperText>{String(schema.description)}</FormHelperText>
      ) : null}
    </FormControl>
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
