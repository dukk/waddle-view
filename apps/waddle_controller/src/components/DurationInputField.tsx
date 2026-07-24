import { useEffect, useMemo, useState } from 'react';
import {
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import {
  clampDurationSeconds,
  durationPartsToSeconds,
  durationUnitLabel,
  formatIntervalDisplay,
  resolveDurationUnit,
  secondsToDurationParts,
  type DurationUnit,
} from '@/util/durationInput';

type Props = {
  label: string;
  valueSeconds: number;
  onChange: (seconds: number) => void;
  allowedUnits?: readonly DurationUnit[];
  /** Initial unit when [preferred] is allowed; defaults to minutes. */
  defaultUnit?: DurationUnit;
  minSeconds?: number;
  maxSeconds?: number;
  disabled?: boolean;
  helperText?: string;
};

export function DurationInputField({
  label,
  valueSeconds,
  onChange,
  allowedUnits = ['sec', 'min', 'hr', 'day'],
  defaultUnit = 'min',
  minSeconds,
  maxSeconds,
  disabled,
  helperText,
}: Props) {
  const units = useMemo(
    () => (allowedUnits.length > 0 ? allowedUnits : (['sec'] as const)),
    [allowedUnits],
  );
  const clampedSeconds = clampDurationSeconds(valueSeconds, minSeconds, maxSeconds);
  const initialUnit = resolveDurationUnit(clampedSeconds, units, defaultUnit);
  const initialParts = secondsToDurationParts(clampedSeconds, initialUnit);
  const [amount, setAmount] = useState(String(initialParts.amount));
  const [unit, setUnit] = useState<DurationUnit>(initialParts.unit);

  useEffect(() => {
    const next = secondsToDurationParts(
      clampDurationSeconds(valueSeconds, minSeconds, maxSeconds),
      unit,
    );
    setAmount(String(next.amount));
  }, [valueSeconds, minSeconds, maxSeconds, unit]);

  const commit = (nextAmount: string, nextUnit: DurationUnit) => {
    const parsed = Number(nextAmount);
    const secs = clampDurationSeconds(
      durationPartsToSeconds(Number.isFinite(parsed) ? parsed : 0, nextUnit),
      minSeconds,
      maxSeconds,
    );
    onChange(secs);
  };

  const summary = formatIntervalDisplay(clampedSeconds);

  return (
    <Stack spacing={0.5}>
      <Typography variant="body2" component="label">
        {label}
      </Typography>
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} sx={{
        alignItems: "flex-start"
      }}>
        <TextField
          type="number"
          value={amount}
          onChange={(e) => {
            setAmount(e.target.value);
            commit(e.target.value, unit);
          }}
          disabled={disabled}
          size="small"
          sx={{ minWidth: 120 }}
          slotProps={{
            htmlInput: { min: 0, step: unit === 'sec' ? 1 : 0.1 }
          }}
        />
        <FormControl size="small" sx={{ minWidth: 140 }} disabled={disabled}>
          <InputLabel id={`${label}-unit`}>Unit</InputLabel>
          <Select
            labelId={`${label}-unit`}
            label="Unit"
            value={unit}
            onChange={(e) => {
              const next = e.target.value as DurationUnit;
              setUnit(next);
              commit(amount, next);
            }}
          >
            {units.map((u) => (
              <MenuItem key={u} value={u}>
                {durationUnitLabel(u)}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        <Typography
          variant="body2"
          sx={{
            color: "text.secondary",
            pt: 1
          }}>
          ({summary})
        </Typography>
      </Stack>
      {helperText ? (
        <Typography variant="caption" sx={{
          color: "text.secondary"
        }}>
          {helperText}
        </Typography>
      ) : null}
    </Stack>
  );
}
