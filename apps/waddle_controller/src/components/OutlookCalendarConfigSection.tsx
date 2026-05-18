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
import {
  mergeOutlookCalendarsWithSaved,
  type OutlookCalendarConfigState,
} from '@/util/outlookCalendarConfig';

export type ContentCategoryOption = {
  id: string;
  label: string;
};

type Props = {
  display: SavedDisplay;
  value: OutlookCalendarConfigState;
  onChange: (next: OutlookCalendarConfigState) => void;
  microsoftAccounts: IntegrationAccountRow[];
  categories: ContentCategoryOption[];
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

  const patchCalendar = (id: string, partial: { selected?: boolean; categoryId?: string }) => {
    onChange({
      ...value,
      calendars: value.calendars.map((c) => (c.id === id ? { ...c, ...partial } : c)),
    });
  };

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Outlook calendar sync</Typography>
      {configuredMicrosoftAccounts.length === 0 ? (
        <Alert severity="info">
          Add a Microsoft account under <strong>Accounts &amp; API keys</strong>, complete sign-in on
          the display, then return here.
        </Alert>
      ) : (
        <FormControl fullWidth size="small">
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
          value={value.pastDays}
          onChange={(e) => patch({ pastDays: Number(e.target.value) || 1 })}
          inputProps={{ min: 1 }}
        />
        <TextField
          label="Future days"
          type="number"
          size="small"
          fullWidth
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
                    onChange={(_, checked) => patchCalendar(cal.id, { selected: checked })}
                  />
                }
                label={cal.name}
              />
              <FormControl fullWidth size="small" disabled={!cal.selected}>
                <InputLabel id={`outlook-cal-cat-${cal.id}`}>Event category</InputLabel>
                <Select
                  labelId={`outlook-cal-cat-${cal.id}`}
                  label="Event category"
                  value={cal.categoryId}
                  onChange={(e) => patchCalendar(cal.id, { categoryId: e.target.value })}
                >
                  <MenuItem value="">
                    <em>Default</em>
                  </MenuItem>
                  {categories.map((cat) => (
                    <MenuItem key={cat.id} value={cat.id}>
                      {cat.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Box>
          ))}
        </Stack>
      ) : null}
    </Stack>
  );
}
