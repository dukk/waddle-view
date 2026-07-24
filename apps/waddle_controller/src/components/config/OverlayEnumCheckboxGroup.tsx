import type { ElementType } from 'react';
import {
  Box,
  Checkbox,
  FormControl,
  FormControlLabel,
  FormGroup,
  FormHelperText,
  FormLabel,
  Stack,
} from '@mui/material';

export type OverlayEnumOption = {
  value: string;
  label: string;
  icon?: ElementType;
};

type Props = {
  label: string;
  helperText?: string;
  options: OverlayEnumOption[];
  value: string[];
  onChange: (next: string[]) => void;
  disabled?: boolean;
  /** When set, selecting this value clears other selections (and vice versa). */
  mixValue?: string;
};

export function OverlayEnumCheckboxGroup({
  label,
  helperText,
  options,
  value,
  onChange,
  disabled = false,
  mixValue = 'mix',
}: Props) {
  const toggle = (token: string, checked: boolean) => {
    if (token === mixValue) {
      onChange(checked ? [mixValue] : []);
      return;
    }
    const withoutMix = value.filter((v) => v !== mixValue);
    if (checked) {
      onChange([...withoutMix, token]);
      return;
    }
    onChange(withoutMix.filter((v) => v !== token));
  };

  return (
    <FormControl component="fieldset" variant="standard" disabled={disabled} fullWidth>
      <FormLabel component="legend">{label}</FormLabel>
      {helperText ? <FormHelperText sx={{ mt: 0.25, mb: 1 }}>{helperText}</FormHelperText> : null}
      <FormGroup>
        <Stack direction="row" useFlexGap spacing={0.5} sx={{
          flexWrap: "wrap"
        }}>
          {options.map((opt) => {
            const Icon = opt.icon;
            const checked = value.includes(opt.value);
            return (
              <Box key={opt.value} sx={{ minWidth: 140 }}>
                <FormControlLabel
                  control={
                    <Checkbox
                      size="small"
                      checked={checked}
                      onChange={(_, v) => toggle(opt.value, v)}
                    />
                  }
                  label={
                    <Stack direction="row" spacing={0.75} sx={{
                      alignItems: "center"
                    }}>
                      {Icon ? <Icon sx={{ fontSize: 18, opacity: 0.85 }} /> : null}
                      <span>{opt.label}</span>
                    </Stack>
                  }
                />
              </Box>
            );
          })}
        </Stack>
      </FormGroup>
    </FormControl>
  );
}
