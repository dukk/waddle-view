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
import { fetchMicrosoftGraphCalendars } from '@/api/microsoftGraphCalendars';
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
  mergeOutlookCalendarsWithSaved,
  type OutlookCalendarConfigState,
} from '@/util/outlookCalendarConfig';

export type { ContentCategoryOption };

type Props = {
  display: SavedDisplay;
  value: OutlookCalendarConfigState;
  onChange: (next: OutlookCalendarConfigState) => void;
  microsoftAccounts: IntegrationAccountRow[];
  categories: ContentCategoryOption[];
  disabled?: boolean;
};

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

export function OutlookCalendarConfigSection({
  display,
  value,
  onChange,
  microsoftAccounts,
  categories,
  disabled = false,
}: Props) {
  const [calendarsLoading, setCalendarsLoading] = useState(false);
  const [calendarsError, setCalendarsError] = useState<string | null>(null);

  const configuredMicrosoftAccounts = useMemo(
    () => microsoftAccounts.filter((a) => a.configured),
    [microsoftAccounts],
  );

  const selectedAccount = useMemo(
    () => configuredMicrosoftAccounts.find((a) => a.id === value.graphAccountKey),
    [configuredMicrosoftAccounts, value.graphAccountKey],
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
        const remote = await fetchMicrosoftGraphCalendars(display, accountId);
        onChange({
          ...value,
          graphAccountKey: accountId,
          calendars: mergeOutlookCalendarsWithSaved(remote, savedCalendars),
        });
      } catch (e) {
        setCalendarsError(errMsg(e));
        onChange({ ...value, graphAccountKey: accountId, calendars: [] });
      } finally {
        setCalendarsLoading(false);
      }
    },
    [display, onChange, value],
  );

  useEffect(() => {
    if (!value.graphAccountKey || !selectedAccount) {
      return;
    }
    if (value.calendars.length > 0) {
      return;
    }
    void loadCalendars(value.graphAccountKey);
  }, [value.graphAccountKey, value.calendars.length, selectedAccount, loadCalendars]);

  const patch = (partial: Partial<OutlookCalendarConfigState>) => {
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
      title="Outlook calendar sync"
      description="Choose a signed-in Microsoft account and select which calendars to sync into event categories."
    >
      {configuredMicrosoftAccounts.length === 0 ? (
        <Alert severity="info">
          Add a Microsoft account under <strong>{DISPLAY_SETTINGS_ACCOUNTS_LABEL}</strong>, complete
          sign-in on the display, then return here.
        </Alert>
      ) : (
        <FormControl fullWidth size="small" disabled={disabled}>
          <InputLabel id="outlook-ms-account-label">Microsoft account</InputLabel>
          <Select
            labelId="outlook-ms-account-label"
            label="Microsoft account"
            value={value.graphAccountKey}
            onChange={(e) => {
              const accountId = e.target.value;
              void loadCalendars(accountId, []);
            }}
          >
            {configuredMicrosoftAccounts.map((a) => (
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
          inputProps={{ min: 1 }}
        />
        <TextField
          label="Future days"
          type="number"
          size="small"
          fullWidth
          disabled={disabled}
          value={value.futureDays}
          onChange={(e) => patch({ futureDays: Number(e.target.value) || 1 })}
          inputProps={{ min: 1 }}
        />
      </Stack>
      {value.graphAccountKey ? (
        <Stack spacing={1}>
          <Stack direction="row" alignItems="center" spacing={1}>
            <Typography variant="body2" fontWeight={600}>
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
                onClick={() => void loadCalendars(value.graphAccountKey)}
              >
                Refresh list
              </Typography>
            ) : null}
          </Stack>
          {calendarsError ? <Alert severity="error">{calendarsError}</Alert> : null}
          {!calendarsLoading && value.calendars.length === 0 && !calendarsError ? (
            <Typography variant="body2" color="text.secondary">
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
                id={`outlook-cal-cat-${cal.id}`}
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
