import { Checkbox, FormControlLabel, Stack, Typography } from '@mui/material';
import { ClockOverlayPlacementFields } from './ClockOverlayPlacementFields';

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

export function DigitalClockOverlayConfigForm({ formData, onChange, disabled }: Props) {
  const hour24 = formData.hour24 === true;
  const showSeconds = formData.showSeconds === true;

  const patch = (partial: Record<string, unknown>) => {
    onChange({ ...formData, ...partial });
  };

  return (
    <Stack spacing={2}>
      <Typography variant="body2" sx={{
        color: "text.secondary"
      }}>
        Digital clock and date at a viewport position. Options match the digital clock screen.
      </Typography>
      <FormControlLabel
        control={
          <Checkbox
            checked={hour24}
            disabled={disabled}
            onChange={(e) => patch({ hour24: e.target.checked || undefined })}
          />
        }
        label="24-hour time"
      />
      <FormControlLabel
        control={
          <Checkbox
            checked={showSeconds}
            disabled={disabled}
            onChange={(e) => patch({ showSeconds: e.target.checked || undefined })}
          />
        }
        label="Show seconds"
      />
      <ClockOverlayPlacementFields
        formData={formData}
        onChange={onChange}
        disabled={disabled}
        scaleHelp="Clock block width as a fraction of the viewport shortest side."
      />
    </Stack>
  );
}
