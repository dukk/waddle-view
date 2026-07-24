import type { Dispatch, SetStateAction } from 'react';
import { useConfirmDialog } from '@/hooks/useConfirmDialog';
import {
  Autocomplete,
  Box,
  Button,
  Checkbox,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import { DisplayThemePaletteSwatches } from '@/components/DisplayThemePaletteSwatches';
import { DisplayThemeDialog } from '@/components/DisplayThemeDialog';
import { TickerPixelsPerSecondField } from '@/components/TickerPixelsPerSecondField';
import {
  CURATOR_HISTORY_DEPTH,
  CURATOR_TICKER_PROGRAM_DURATION,
  DISPLAY_COLLECT_IDLE_SECONDS,
  VIEWPORT_RESERVE_PCT,
  curatorTextScaleIds,
} from '@/constants/curatorDisplaySettings';
import DiamondOutlinedIcon from '@mui/icons-material/DiamondOutlined';
import {
  CONTROLLER_DATE_ORDER_OPTIONS,
  CONTROLLER_TIME_FORMAT_OPTIONS,
  DISPLAY_TICKER_SEPARATOR_OPTIONS,
  DISPLAY_WEATHER_TEMPERATURE_UNIT_OPTIONS,
  type DisplaySettings,
  type DisplayTickerSeparator,
} from '@/constants/displaySettings';
import {
  filterDisplayTimezoneOptions,
  type DisplayTimezoneOption,
} from '@/constants/displayTimezoneOptions';
import type { DisplayOperatorSettingsState } from '@/hooks/useDisplayOperatorSettings';
import type { SavedDisplay } from '@/storage/displays';
import type { DisplayThemePickerOption } from '@/constants/displayThemes';

type FieldProps = {
  canWrite: boolean;
  form: DisplaySettings;
  setForm: Dispatch<SetStateAction<DisplaySettings>>;
};

export function DisplayOperatorSettingsGeneralFields({
  canWrite,
  form,
  setForm,
  timezoneOptions,
  selectedTimezone,
}: FieldProps & {
  timezoneOptions: DisplayTimezoneOption[];
  selectedTimezone: DisplayTimezoneOption | null;
}) {
  return (
    <>
      <FormControl fullWidth disabled={!canWrite}>
        <InputLabel id="time-format-label">Time format</InputLabel>
        <Select
          labelId="time-format-label"
          label="Time format"
          value={form.controller_time_format}
          onChange={(e) =>
            setForm({
              ...form,
              controller_time_format: e.target.value as DisplaySettings['controller_time_format'],
            })
          }
        >
          {CONTROLLER_TIME_FORMAT_OPTIONS.map((o) => (
            <MenuItem key={o.value} value={o.value}>
              {o.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <FormControl fullWidth disabled={!canWrite}>
        <InputLabel id="date-order-label">Date format</InputLabel>
        <Select
          labelId="date-order-label"
          label="Date format"
          value={form.controller_date_order}
          onChange={(e) =>
            setForm({
              ...form,
              controller_date_order: e.target.value as DisplaySettings['controller_date_order'],
            })
          }
        >
          {CONTROLLER_DATE_ORDER_OPTIONS.map((o) => (
            <MenuItem key={o.value} value={o.value}>
              {o.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <Box>
        <Autocomplete
          fullWidth
          disabled={!canWrite}
          options={timezoneOptions}
          value={selectedTimezone}
          onChange={(_, option) => {
            if (option) setForm({ ...form, display_timezone: option.id });
          }}
          getOptionLabel={(option) => option.label}
          isOptionEqualToValue={(a, b) => a.id === b.id}
          filterOptions={(options, state) =>
            filterDisplayTimezoneOptions(options, state.inputValue)
          }
          renderInput={(params) => <TextField {...params} label="Display timezone" />}
        />
        <Typography
          variant="caption"
          sx={{
            color: "text.secondary",
            mt: 0.75,
            display: 'block'
          }}>
          Stored as <code>display.timezone</code>. Invalid ids fall back on the display. Type to
          filter {timezoneOptions.length} IANA zones.
        </Typography>
      </Box>
      <FormControl fullWidth disabled={!canWrite}>
        <InputLabel id="weather-temp-unit-label">Weather temperature</InputLabel>
        <Select
          labelId="weather-temp-unit-label"
          label="Weather temperature"
          value={form.display_weather_temperature_unit}
          onChange={(e) =>
            setForm({
              ...form,
              display_weather_temperature_unit: e.target
                .value as DisplaySettings['display_weather_temperature_unit'],
            })
          }
        >
          {DISPLAY_WEATHER_TEMPERATURE_UNIT_OPTIONS.map((o) => (
            <MenuItem key={o.value} value={o.value}>
              {o.label}
            </MenuItem>
          ))}
        </Select>
        <Typography
          variant="caption"
          sx={{
            color: "text.secondary",
            mt: 0.75,
            display: 'block'
          }}>
          Stored as <code>display.weather.temperature_unit</code>. Default is Fahrenheit when unset.
          Applies to ticker weather and weather slides unless a tape overrides it.
        </Typography>
      </FormControl>
      <Typography variant="subtitle2" sx={{
        fontWeight: 600
      }}>
        Viewport edge reserve
      </Typography>
      <Typography
        variant="caption"
        sx={{
          color: "text.secondary",
          display: 'block',
          mt: -1
        }}>
        Percent of the letterboxed TV viewport reserved on each edge. Shrinks both screen slides and
        the ticker so you can place always-on overlays (for example a clock or date) in the margin.
        Use display overlays for the widgets themselves.
      </Typography>
      <CuratorSliderField
        label="Top reserve (%)"
        value={form.display_viewport_reserve_top_pct}
        onChange={(v) => setForm({ ...form, display_viewport_reserve_top_pct: v })}
        min={VIEWPORT_RESERVE_PCT.min}
        max={VIEWPORT_RESERVE_PCT.max}
        step={VIEWPORT_RESERVE_PCT.step}
        disabled={!canWrite}
      />
      <CuratorSliderField
        label="Right reserve (%)"
        value={form.display_viewport_reserve_right_pct}
        onChange={(v) => setForm({ ...form, display_viewport_reserve_right_pct: v })}
        min={VIEWPORT_RESERVE_PCT.min}
        max={VIEWPORT_RESERVE_PCT.max}
        step={VIEWPORT_RESERVE_PCT.step}
        disabled={!canWrite}
      />
      <CuratorSliderField
        label="Bottom reserve (%)"
        value={form.display_viewport_reserve_bottom_pct}
        onChange={(v) => setForm({ ...form, display_viewport_reserve_bottom_pct: v })}
        min={VIEWPORT_RESERVE_PCT.min}
        max={VIEWPORT_RESERVE_PCT.max}
        step={VIEWPORT_RESERVE_PCT.step}
        disabled={!canWrite}
      />
      <CuratorSliderField
        label="Left reserve (%)"
        value={form.display_viewport_reserve_left_pct}
        onChange={(v) => setForm({ ...form, display_viewport_reserve_left_pct: v })}
        min={VIEWPORT_RESERVE_PCT.min}
        max={VIEWPORT_RESERVE_PCT.max}
        step={VIEWPORT_RESERVE_PCT.step}
        disabled={!canWrite}
      />
    </>
  );
}

export function DisplayOperatorSettingsThemeFields({
  canWrite,
  display,
  form,
  setForm,
  settings,
  onKvChanged,
}: FieldProps & {
  display: SavedDisplay;
  settings: DisplayOperatorSettingsState;
  onKvChanged: () => void;
}) {
  const { confirm, ConfirmDialogHost } = useConfirmDialog();
  const { themeOptions, displayThemeOptionById: themeById } = settings;

  return (
    <>
      <FormControl fullWidth disabled={!canWrite}>
        <InputLabel id="theme-label">Display theme</InputLabel>
        <Select
          labelId="theme-label"
          label="Display theme"
          value={form.display_theme_id}
          onChange={(e) => setForm({ ...form, display_theme_id: String(e.target.value) })}
          renderValue={(value) => {
            const theme = themeById(themeOptions, String(value));
            if (!theme) {
              return value;
            }
            return (
              <Stack
                direction="row"
                spacing={1}
                sx={{
                  alignItems: "center",
                  width: '100%',
                  pr: 0.5
                }}>
                <Box
                  component="span"
                  sx={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis' }}
                >
                  {theme.label}
                </Box>
                <DisplayThemePaletteSwatches groups={theme.preview} />
              </Stack>
            );
          }}
        >
          {themeOptions.map((t: DisplayThemePickerOption) => (
            <MenuItem key={t.id} value={t.id} sx={{ gap: 1 }}>
              <Box component="span" sx={{ flex: 1 }}>
                {t.label}
                {t.isCustom ? ' (custom)' : ''}
              </Box>
              <DisplayThemePaletteSwatches groups={t.preview} />
            </MenuItem>
          ))}
        </Select>
        <Typography
          variant="caption"
          sx={{
            color: "text.secondary",
            mt: 0.75,
            display: 'block'
          }}>
          Swatches (left to right): display background, screen chrome, ticker chrome, then four
          accents.
        </Typography>
      </FormControl>
      <Box>
        <Stack
          direction="row"
          sx={{
            alignItems: "center",
            justifyContent: "space-between",
            mb: 1
          }}>
          <Typography variant="subtitle2" sx={{
            fontWeight: 600
          }}>
            Custom themes
          </Typography>
          <Button
            size="small"
            variant="outlined"
            disabled={!canWrite}
            onClick={() => {
              settings.setThemeDialogEdit(null);
              settings.setThemeDialogOpen(true);
            }}
          >
            Create theme
          </Button>
        </Stack>
        {(form.display_custom_themes ?? []).length === 0 ? (
          <Typography variant="body2" sx={{
            color: "text.secondary"
          }}>
            No custom themes yet. Built-in presets are always available above.
          </Typography>
        ) : (
          <Stack spacing={1}>
            {(form.display_custom_themes ?? []).map((t) => (
              <Stack
                key={t.id}
                direction="row"
                spacing={1}
                sx={{
                  alignItems: "center",
                  py: 0.75,
                  px: 1,
                  borderRadius: 1,
                  border: '1px solid',
                  borderColor: 'divider'
                }}>
                <Box component="span" sx={{ flex: 1, minWidth: 0 }}>
                  <Typography variant="body2">{t.label}</Typography>
                  <Typography variant="caption" sx={{
                    color: "text.secondary"
                  }}>
                    {t.id}
                  </Typography>
                </Box>
                <DisplayThemePaletteSwatches groups={t.preview} />
                <Button
                  size="small"
                  disabled={!canWrite}
                  onClick={() => {
                    settings.setThemeDialogEdit(t);
                    settings.setThemeDialogOpen(true);
                  }}
                >
                  Edit
                </Button>
                <Button
                  size="small"
                  color="error"
                  disabled={!canWrite}
                  onClick={() => {
                    void (async () => {
                      const ok = await confirm({
                        title: 'Delete custom theme?',
                        message: `Delete custom theme "${t.label}"? The display will fall back to the default if it is active.`,
                        confirmLabel: 'Delete',
                        severity: 'error',
                      });
                      if (!ok) return;
                      await settings.deleteCustomTheme(t).catch(() => {});
                    })();
                  }}
                >
                  Delete
                </Button>
              </Stack>
            ))}
          </Stack>
        )}
      </Box>
      <DisplayThemeDialog
        open={settings.themeDialogOpen}
        display={display}
        theme={settings.themeDialogEdit}
        onClose={() => settings.setThemeDialogOpen(false)}
        onSaved={onKvChanged}
      />
      <ConfirmDialogHost />
      <FormControl fullWidth disabled={!canWrite}>
        <InputLabel id="screen-scale">Screen text scale</InputLabel>
        <Select
          labelId="screen-scale"
          label="Screen text scale"
          value={form.display_text_scale_screen}
          onChange={(e) => setForm({ ...form, display_text_scale_screen: String(e.target.value) })}
        >
          {curatorTextScaleIds.map((id) => (
            <MenuItem key={id} value={id}>
              {id}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <FormControl fullWidth disabled={!canWrite}>
        <InputLabel id="ticker-scale">Ticker text scale</InputLabel>
        <Select
          labelId="ticker-scale"
          label="Ticker text scale"
          value={form.display_text_scale_ticker}
          onChange={(e) => setForm({ ...form, display_text_scale_ticker: String(e.target.value) })}
        >
          {curatorTextScaleIds.map((id) => (
            <MenuItem key={`t-${id}`} value={id}>
              {id}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
    </>
  );
}

export function DisplayOperatorSettingsProgramsFields({
  canWrite,
  form,
  setForm,
}: FieldProps) {
  return (
    <>
      <CuratorSliderField
        label="Program history depth"
        value={form.display_program_history_depth}
        onChange={(v) => setForm({ ...form, display_program_history_depth: v })}
        min={CURATOR_HISTORY_DEPTH.min}
        max={CURATOR_HISTORY_DEPTH.max}
        step={CURATOR_HISTORY_DEPTH.step}
        disabled={!canWrite}
      />
      <Typography
        variant="caption"
        sx={{
          color: "text.secondary",
          mt: -1.5,
          display: 'block'
        }}>
        How many past screen programs are kept for back-navigation and how many recent screen
        placements influence frequency weighting. Shared across all curator configurations. Does not
        control how many entries appear on the Programs page (that page shows up to 10 recent
        telemetry snapshots).
      </Typography>
      <Typography variant="subtitle2" sx={{
        fontWeight: 600
      }}>
        Ticker marquee
      </Typography>
      <Typography
        variant="caption"
        sx={{
          color: "text.secondary",
          display: 'block',
          mt: -1
        }}>
        Default scroll speed and RSS scroll budget for the bottom ticker. Curator configurations
        can override these when they are the active primary program.
      </Typography>
      <CuratorSliderField
        label="Ticker program duration"
        value={form.display_ticker_program_duration_seconds}
        onChange={(v) => setForm({ ...form, display_ticker_program_duration_seconds: v })}
        min={CURATOR_TICKER_PROGRAM_DURATION.min}
        max={CURATOR_TICKER_PROGRAM_DURATION.max}
        step={CURATOR_TICKER_PROGRAM_DURATION.step}
        disabled={!canWrite}
        formatValue={(v) => `${v}s`}
      />
      <TickerPixelsPerSecondField
        value={form.display_ticker_pixels_per_second}
        onChange={(v) => setForm({ ...form, display_ticker_pixels_per_second: v })}
        disabled={!canWrite}
      />
      <FormControl fullWidth disabled={!canWrite}>
        <InputLabel id="ticker-item-separator-label">Between ticker items</InputLabel>
        <Select
          labelId="ticker-item-separator-label"
          label="Between ticker items"
          value={form.display_ticker_item_separator}
          onChange={(e) =>
            setForm({
              ...form,
              display_ticker_item_separator: e.target.value as DisplayTickerSeparator,
            })
          }
        >
          {DISPLAY_TICKER_SEPARATOR_OPTIONS.map((o) => (
            <MenuItem key={o.value} value={o.value}>
              <TickerSeparatorMenuLabel kind={o.value} label={o.label} />
            </MenuItem>
          ))}
        </Select>
        <Typography
          variant="caption"
          sx={{
            color: "text.secondary",
            mt: 0.75,
            display: 'block'
          }}>
          Stored as <code>display.ticker.item_separator</code>. Separator between lines within one
          ticker program.
        </Typography>
      </FormControl>
      <FormControl fullWidth disabled={!canWrite}>
        <InputLabel id="ticker-program-separator-label">Between ticker programs</InputLabel>
        <Select
          labelId="ticker-program-separator-label"
          label="Between ticker programs"
          value={form.display_ticker_program_separator}
          onChange={(e) =>
            setForm({
              ...form,
              display_ticker_program_separator: e.target.value as DisplayTickerSeparator,
            })
          }
        >
          {DISPLAY_TICKER_SEPARATOR_OPTIONS.map((o) => (
            <MenuItem key={`p-${o.value}`} value={o.value}>
              <TickerSeparatorMenuLabel kind={o.value} label={o.label} />
            </MenuItem>
          ))}
        </Select>
        <Typography
          variant="caption"
          sx={{
            color: "text.secondary",
            mt: 0.75,
            display: 'block'
          }}>
          Stored as <code>display.ticker.program_separator</code>. Separator when auto-scroll shows
          multiple past ticker programs.
        </Typography>
      </FormControl>
      <Typography
        variant="subtitle2"
        sx={{
          fontWeight: 600,
          pt: 1
        }}>
        CPU / background load
      </Typography>
      <Typography
        variant="caption"
        sx={{
          color: "text.secondary",
          display: 'block',
          mt: -1
        }}>
        Throttles integration polling and optional low-power UI caps on this display.
      </Typography>
      <CuratorSliderField
        label="Collection cycle idle"
        value={form.display_collect_idle_seconds ?? DISPLAY_COLLECT_IDLE_SECONDS.default}
        onChange={(v) => setForm({ ...form, display_collect_idle_seconds: v })}
        min={DISPLAY_COLLECT_IDLE_SECONDS.min}
        max={DISPLAY_COLLECT_IDLE_SECONDS.max}
        step={DISPLAY_COLLECT_IDLE_SECONDS.step}
        disabled={!canWrite}
        formatValue={(v) => `${v}s`}
      />
      <FormControlLabel
        control={
          <Checkbox
            checked={form.display_low_power_enabled === true}
            disabled={!canWrite}
            onChange={(e) =>
              setForm({ ...form, display_low_power_enabled: e.target.checked })
            }
          />
        }
        label="Low-power mode (floor collect idle at 60s, cap ticker at 40 px/s)"
      />
    </>
  );
}

function TickerSeparatorMenuLabel({
  kind,
  label,
}: {
  kind: DisplayTickerSeparator;
  label: string;
}) {
  return (
    <Stack direction="row" spacing={1} sx={{
      alignItems: "center"
    }}>
      {kind === 'diamond' ? (
        <DiamondOutlinedIcon fontSize="small" />
      ) : (
        <Typography component="span" variant="body2" sx={{ fontWeight: 600 }}>
          ·
        </Typography>
      )}
      <span>{label}</span>
    </Stack>
  );
}
