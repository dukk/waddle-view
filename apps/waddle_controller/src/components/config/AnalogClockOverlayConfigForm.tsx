import {
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Typography,
} from '@mui/material';
import {
  ANALOG_DIAL_LABELS_OPTIONS,
  THEME_ACCENT_OPTIONS,
} from '@/constants/clockEnumLabels';
import { ClockOverlayPlacementFields } from './ClockOverlayPlacementFields';

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

function readString(raw: unknown, fallback: string): string {
  return typeof raw === 'string' && raw.trim() ? raw.trim() : fallback;
}

export function AnalogClockOverlayConfigForm({ formData, onChange, disabled }: Props) {
  const dialLabels = readString(formData.dialLabels, 'none');
  const hourHandAccent = readString(formData.hourHandAccent, 'accent1');
  const minuteHandAccent = readString(formData.minuteHandAccent, 'accent2');
  const secondHandAccent = readString(formData.secondHandAccent, 'accent3');

  const patch = (partial: Record<string, unknown>) => {
    onChange({ ...formData, ...partial });
  };

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Analog clock and date at a viewport position. Options match the analog clock screen.
      </Typography>
      <FormControl fullWidth size="small" disabled={disabled}>
        <InputLabel id="analog-overlay-dial-labels">Dial labels</InputLabel>
        <Select
          labelId="analog-overlay-dial-labels"
          label="Dial labels"
          value={dialLabels}
          onChange={(e) => {
            const v = e.target.value;
            patch({ dialLabels: v === 'none' ? undefined : v });
          }}
        >
          {ANALOG_DIAL_LABELS_OPTIONS.map((o) => (
            <MenuItem key={o.value} value={o.value}>
              {o.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <FormControl fullWidth size="small" disabled={disabled}>
        <InputLabel id="analog-overlay-hour-hand">Hour hand accent</InputLabel>
        <Select
          labelId="analog-overlay-hour-hand"
          label="Hour hand accent"
          value={hourHandAccent}
          onChange={(e) => {
            const v = e.target.value;
            patch({ hourHandAccent: v === 'accent1' ? undefined : v });
          }}
        >
          {THEME_ACCENT_OPTIONS.map((o) => (
            <MenuItem key={`hour-${o.value}`} value={o.value}>
              {o.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <FormControl fullWidth size="small" disabled={disabled}>
        <InputLabel id="analog-overlay-minute-hand">Minute hand accent</InputLabel>
        <Select
          labelId="analog-overlay-minute-hand"
          label="Minute hand accent"
          value={minuteHandAccent}
          onChange={(e) => {
            const v = e.target.value;
            patch({ minuteHandAccent: v === 'accent2' ? undefined : v });
          }}
        >
          {THEME_ACCENT_OPTIONS.map((o) => (
            <MenuItem key={`minute-${o.value}`} value={o.value}>
              {o.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <FormControl fullWidth size="small" disabled={disabled}>
        <InputLabel id="analog-overlay-second-hand">Second hand accent</InputLabel>
        <Select
          labelId="analog-overlay-second-hand"
          label="Second hand accent"
          value={secondHandAccent}
          onChange={(e) => {
            const v = e.target.value;
            patch({ secondHandAccent: v === 'accent3' ? undefined : v });
          }}
        >
          {THEME_ACCENT_OPTIONS.map((o) => (
            <MenuItem key={`second-${o.value}`} value={o.value}>
              {o.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <ClockOverlayPlacementFields
        formData={formData}
        onChange={onChange}
        disabled={disabled}
        scaleHelp="Dial diameter as a fraction of the viewport shortest side."
      />
    </Stack>
  );
}
