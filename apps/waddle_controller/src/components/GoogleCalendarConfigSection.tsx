import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Checkbox,
  CircularProgress,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { fetchGoogleCalendars } from '@/api/googleCalendars';
import { ApiError } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import type { IntegrationAccountRow } from '@/util/integrationAccounts';
import { DISPLAY_SETTINGS_ACCOUNTS_LABEL } from '@/constants/displaySettingsTabs';
import {
  CategoryMultiSelect,
  type ContentCategoryOption,
} from '@/components/CategoryMultiSelect';
import { IntegrationConfigSection } from '@/components/IntegrationConfigSection';
import {
  mergeGoogleCalendarsWithSaved,
  type GoogleCalendarConfigState,
} from '@/util/googleCalendarConfig';

export type { ContentCategoryOption };

type Props = {
  display: SavedDisplay;
  value: GoogleCalendarConfigState;
  onChange: (next: GoogleCalendarConfigState) => void;
  googleAccounts: IntegrationAccountRow[];
  categories: ContentCategoryOption[];
  disabled?: boolean;
};

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

export function GoogleCalendarConfigSection({
  display,
  value,
  onChange,
  googleAccounts,
  categories,
  disabled = false,
}: Props) {
  const [calendarsLoading, setCalendarsLoading] = useState(false);
  const [calendarsError, setCalendarsError] = useState<string | null>(null);

  const configuredGoogleAccounts = useMemo(
    () => googleAccounts.filter((a) => a.configured),
    [googleAccounts],
  );

  const selectedAccount = useMemo(
    () => configuredGoogleAccounts.find((a) => a.id === value.googleAccountKey),
    [configuredGoogleAccounts, value.googleAccountKey],
  );

  const loadCalendars = useCallback(
    async (accountId: string, savedCalendars = value.calendars) => {
      if (!accountId) {
        onChange({ ...value, calendars: [] });
        return;
      }
      setCalendarsLoading(true);
      setCalendarsError(null);
      try {
        const remote = await fetchGoogleCalendars(display, accountId);
        onChange({
          ...value,
          googleAccountKey: accountId,
          calendars: mergeGoogleCalendarsWithSaved(remote, savedCalendars),
        });
      } catch (e) {
        setCalendarsError(errMsg(e));
        onChange({ ...value, googleAccountKey: accountId, calendars: [] });
      } finally {
        setCalendarsLoading(false);
      }
    },
    [display, onChange, value],
  );

  useEffect(() => {
    if (!value.googleAccountKey || !selectedAccount) {
      return;
    }
    if (value.calendars.length > 0) {
      return;
    }
    void loadCalendars(value.googleAccountKey);
  }, [value.googleAccountKey, value.calendars.length, selectedAccount, loadCalendars]);

  const patch = (partial: Partial<GoogleCalendarConfigState>) => {
    onChange({ ...value, ...partial });
  };

  const patchCalendar = (
    id: string,
    partial: { selected?: boolean; categoryIds?: string[] },
  ) => {
    onChange({
      ...value,
      calendars: value.calendars.map((c) => (c.id === id ? { ...c, ...partial } : c)),
    });
  };

  return (
    <IntegrationConfigSection
      title="Google Calendar sync"
      description="Choose a signed-in Google account and select which calendars to sync into event categories."
    >
      {configuredGoogleAccounts.length === 0 ? (
        <Alert severity="info">
          Add a Google account under <strong>{DISPLAY_SETTINGS_ACCOUNTS_LABEL}</strong>, complete
          sign-in on the display, then return here.
        </Alert>
      ) : (
        <FormControl fullWidth size="small" disabled={disabled}>
          <InputLabel id="google-cal-account-label">Google account</InputLabel>
          <Select
            labelId="google-cal-account-label"
            label="Google account"
            value={value.googleAccountKey}
            onChange={(e) => {
              const accountId = e.target.value;
              void loadCalendars(accountId, []);
            }}
          >
            {configuredGoogleAccounts.map((a) => (
              <MenuItem key={a.id} value={a.id}>
                {a.label}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      )}
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
        <TextField
          label="Past days"
          type="number"
          size="small"
          fullWidth
          disabled={disabled}
          value={value.pastDays}
          onChange={(e) => patch({ pastDays: Number(e.target.value) || 1 })}
          slotProps={{
            htmlInput: { min: 1 }
          }}
        />
        <TextField
          label="Future days"
          type="number"
          size="small"
          fullWidth
          disabled={disabled}
          value={value.futureDays}
          onChange={(e) => patch({ futureDays: Number(e.target.value) || 1 })}
          slotProps={{
            htmlInput: { min: 1 }
          }}
        />
      </Stack>
      {value.googleAccountKey ? (
        <Stack spacing={1}>
          <Stack direction="row" spacing={1} sx={{
            alignItems: "center"
          }}>
            <Typography variant="body2" sx={{
              fontWeight: 600
            }}>
              Calendars to sync
            </Typography>
            {calendarsLoading ? <CircularProgress size={16} /> : null}
            {!calendarsLoading && selectedAccount ? (
              <Typography
                component="button"
                type="button"
                variant="caption"
                color="primary"
                sx={{ border: 0, background: 'none', cursor: 'pointer', p: 0 }}
                disabled={disabled}
                onClick={() => void loadCalendars(value.googleAccountKey)}
              >
                Refresh list
              </Typography>
            ) : null}
          </Stack>
          {calendarsError ? <Alert severity="error">{calendarsError}</Alert> : null}
          {!calendarsLoading && value.calendars.length === 0 && !calendarsError ? (
            <Typography variant="body2" sx={{
              color: "text.secondary"
            }}>
              No calendars returned for this account. Complete sign-in on the display, then refresh.
            </Typography>
          ) : null}
          {value.calendars.map((cal) => (
            <Box
              key={cal.id}
              sx={{
                display: 'grid',
                gridTemplateColumns: { xs: '1fr', sm: 'auto 1fr' },
                gap: 1,
                alignItems: 'center',
              }}
            >
              <FormControlLabel
                control={
                  <Checkbox
                    checked={cal.selected}
                    disabled={disabled}
                    onChange={(_, checked) => patchCalendar(cal.id, { selected: checked })}
                  />
                }
                label={cal.name}
              />
              <CategoryMultiSelect
                id={`google-cal-cat-${cal.id}`}
                label="Event categories"
                value={cal.categoryIds}
                onChange={(categoryIds) => patchCalendar(cal.id, { categoryIds })}
                categories={categories}
                disabled={disabled || !cal.selected}
              />
            </Box>
          ))}
        </Stack>
      ) : null}
    </IntegrationConfigSection>
  );
}
