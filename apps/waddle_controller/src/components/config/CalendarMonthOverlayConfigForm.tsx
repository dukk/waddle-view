import { Stack, TextField, Typography } from '@mui/material';
import { ClockOverlayPlacementFields } from './ClockOverlayPlacementFields';

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

function readOptionalString(raw: unknown): string {
  return typeof raw === 'string' ? raw.trim() : '';
}

export function CalendarMonthOverlayConfigForm({ formData, onChange, disabled }: Props) {
  const categoryId = readOptionalString(formData.categoryId);

  const patch = (partial: Record<string, unknown>) => {
    onChange({ ...formData, ...partial });
  };

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Compact month grid at a viewport position. Styling matches the calendar month screen.
      </Typography>
      <TextField
        label="Category filter (optional)"
        size="small"
        fullWidth
        disabled={disabled}
        value={categoryId}
        onChange={(e) => {
          const v = e.target.value.trim();
          patch({ categoryId: v || undefined });
        }}
        helperText="content_categories id; leave empty for all events"
      />
      <ClockOverlayPlacementFields
        formData={formData}
        onChange={onChange}
        disabled={disabled}
        scaleHelp="Overlay block width as a fraction of the viewport shortest side."
      />
    </Stack>
  );
}
