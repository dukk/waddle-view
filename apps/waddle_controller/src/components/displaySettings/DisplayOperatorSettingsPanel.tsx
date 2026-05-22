import { Alert, Box, Button, Stack, Typography } from '@mui/material';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import {
  DisplayOperatorSettingsGeneralFields,
  DisplayOperatorSettingsProgramsFields,
  DisplayOperatorSettingsThemeFields,
} from '@/components/displaySettings/DisplayOperatorSettingsFields';
import type { DisplayOperatorSettingsState } from '@/hooks/useDisplayOperatorSettings';
import type { SavedDisplay } from '@/storage/displays';

export type DisplayOperatorSettingsPanelVariant = 'general' | 'theme' | 'programs';

const PANEL_COPY: Record<
  DisplayOperatorSettingsPanelVariant,
  { title: string; description: string }
> = {
  general: {
    title: 'General',
    description:
      'Wall-clock timezone, weather temperature unit, controller timestamp formatting, and viewport edge reserve for this display.',
  },
  theme: {
    title: 'Theme',
    description: 'Display color theme and screen/ticker text scale for this display.',
  },
  programs: {
    title: 'Programs',
    description:
      'Program history depth and default ticker marquee scroll settings. Curator configurations can override ticker values when active.',
  },
};

export function DisplayOperatorSettingsPanel({
  variant,
  display,
  canWrite,
  settings,
  onKvChanged,
}: {
  variant: DisplayOperatorSettingsPanelVariant;
  display: SavedDisplay;
  canWrite: boolean;
  settings: DisplayOperatorSettingsState;
  onKvChanged: () => void;
}) {
  const copy = PANEL_COPY[variant];
  const { loading, error, saved, setSaved, form, setForm, save } = settings;

  return (
    <Box>
      <DisplayRefreshIndicator loading={loading} />
      <Typography variant="subtitle1" fontWeight={600} gutterBottom>
        {copy.title}
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        {copy.description}
      </Typography>
      {error && (
        <Alert severity="error" sx={{ mb: 1 }}>
          {error}
        </Alert>
      )}
      {saved && (
        <Alert severity="success" sx={{ mb: 1 }} onClose={() => setSaved(false)}>
          Saved.
        </Alert>
      )}
      <Stack spacing={2.5}>
        {variant === 'general' && (
          <DisplayOperatorSettingsGeneralFields
            canWrite={canWrite}
            form={form}
            setForm={setForm}
            timezoneOptions={settings.timezoneOptions}
            selectedTimezone={settings.selectedTimezone}
          />
        )}
        {variant === 'theme' && (
          <DisplayOperatorSettingsThemeFields
            canWrite={canWrite}
            display={display}
            form={form}
            setForm={setForm}
            settings={settings}
            onKvChanged={onKvChanged}
          />
        )}
        {variant === 'programs' && (
          <DisplayOperatorSettingsProgramsFields canWrite={canWrite} form={form} setForm={setForm} />
        )}
        {canWrite && (
          <Button variant="contained" onClick={() => void save()}>
            Save display settings
          </Button>
        )}
      </Stack>
    </Box>
  );
}

export function DisplayOperatorSettingsLoading() {
  return (
    <Stack spacing={1}>
      <Typography variant="body2" color="text.secondary">
        Loading display settings…
      </Typography>
    </Stack>
  );
}
