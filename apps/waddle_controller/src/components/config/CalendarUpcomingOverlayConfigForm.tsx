import { Checkbox, FormControlLabel, Stack, TextField, Typography } from '@mui/material';
import { ClockOverlayPlacementFields } from './ClockOverlayPlacementFields';

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

function readOptionalString(raw: unknown): string {
  return typeof raw === 'string' ? raw.trim() : '';
}

function readUpcomingDays(raw: unknown): number {
  if (typeof raw === 'number' && Number.isFinite(raw)) {
    return Math.min(14, Math.max(1, Math.round(raw)));
  }
  return 5;
}

export function CalendarUpcomingOverlayConfigForm({ formData, onChange, disabled }: Props) {
  const categoryId = readOptionalString(formData.categoryId);
  const upcomingDays = readUpcomingDays(formData.upcomingDays);
  const upcomingTime12Hour = formData.upcomingTime12Hour !== false;
  const noonLabel = readOptionalString(formData.upcomingTimeNoonLabel) || 'Noon';

  const patch = (partial: Record<string, unknown>) => {
    onChange({ ...formData, ...partial });
  };

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Upcoming calendar events at a viewport position. Options match the calendar month screen
        upcoming column.
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
      <TextField
        label="Upcoming days"
        type="number"
        size="small"
        fullWidth
        disabled={disabled}
        inputProps={{ min: 1, max: 14, step: 1 }}
        value={upcomingDays}
        onChange={(e) => {
          const n = Number.parseInt(e.target.value, 10);
          if (!Number.isFinite(n)) {
            return;
          }
          patch({
            upcomingDays: Math.min(14, Math.max(1, n)) === 5 ? undefined : n,
          });
        }}
        helperText="Days ahead from today (1–14, default 5)"
      />
      <FormControlLabel
        control={
          <Checkbox
            checked={upcomingTime12Hour}
            disabled={disabled}
            onChange={(e) => patch({ upcomingTime12Hour: e.target.checked })}
          />
        }
        label="12-hour times with AM/PM"
      />
      <TextField
        label="Noon label"
        size="small"
        fullWidth
        disabled={disabled}
        value={noonLabel}
        onChange={(e) => {
          const v = e.target.value.trim();
          patch({ upcomingTimeNoonLabel: v === 'Noon' ? undefined : v });
        }}
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
