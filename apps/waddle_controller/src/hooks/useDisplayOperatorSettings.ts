import { useCallback, useEffect, useMemo, useState, type Dispatch, type SetStateAction } from 'react';
import { deleteDisplayTheme } from '@/api/displayThemes';
import { putDisplaySettings, fetchDisplaySettings } from '@/api/displaySettings';
import { ApiError } from '@/api/client';
import {
  CURATOR_HISTORY_DEPTH,
  CURATOR_TICKER_PIXELS_PER_SECOND,
  CURATOR_TICKER_PROGRAM_DURATION,
  VIEWPORT_RESERVE_PCT,
  curatorThemeIds,
} from '@/constants/curatorDisplaySettings';
import type { DisplayCustomTheme } from '@/constants/displayThemes';
import {
  normalizeDisplayWeatherTemperatureUnit,
  type DisplaySettings,
} from '@/constants/displaySettings';
import {
  displayTimezoneSelectOptions,
  type DisplayTimezoneOption,
} from '@/constants/displayTimezoneOptions';
import { useDisplayFormat } from '@/context/DisplayFormatContext';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import type { SavedDisplay } from '@/storage/displays';
import type { DisplayThemePickerOption } from '@/constants/displayThemes';
import {
  displayThemeOptionById,
  mergeBuiltinAndCustomThemes,
} from '@/util/displayThemeOptions';

export type DisplayOperatorSettingsState = {
  loading: boolean;
  initialized: boolean;
  error: string | null;
  saved: boolean;
  setSaved: (v: boolean) => void;
  form: DisplaySettings;
  setForm: Dispatch<SetStateAction<DisplaySettings>>;
  save: () => Promise<void>;
  themeOptions: DisplayThemePickerOption[];
  timezoneOptions: DisplayTimezoneOption[];
  selectedTimezone: DisplayTimezoneOption | null;
  themeDialogOpen: boolean;
  setThemeDialogOpen: (v: boolean) => void;
  themeDialogEdit: DisplayCustomTheme | null;
  setThemeDialogEdit: (v: DisplayCustomTheme | null) => void;
  deleteCustomTheme: (theme: DisplayCustomTheme) => Promise<void>;
  displayThemeOptionById: typeof displayThemeOptionById;
};

export function useDisplayOperatorSettings(
  display: SavedDisplay,
  kvWriteTick: number,
  onKvChanged: () => void,
): DisplayOperatorSettingsState | null {
  const { refresh: refreshFormat } = useDisplayFormat();
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [initialized, setInitialized] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [form, setForm] = useState<DisplaySettings | null>(null);
  const [themeDialogOpen, setThemeDialogOpen] = useState(false);
  const [themeDialogEdit, setThemeDialogEdit] = useState<DisplayCustomTheme | null>(null);

  const themeOptions = useMemo(
    () =>
      mergeBuiltinAndCustomThemes(curatorThemeIds, form?.display_custom_themes ?? []),
    [form?.display_custom_themes],
  );

  const timezoneOptions = useMemo(
    () => (form ? displayTimezoneSelectOptions(form.display_timezone) : []),
    [form],
  );

  const selectedTimezone = useMemo((): DisplayTimezoneOption | null => {
    if (!form) return null;
    return (
      timezoneOptions.find((o) => o.id === form.display_timezone) ?? {
        id: form.display_timezone,
        label: `${form.display_timezone} (custom)`,
      }
    );
  }, [form, timezoneOptions]);

  const load = useCallback(async () => {
    await wrapRefresh(async () => {
      setError(null);
      try {
        const data = await fetchDisplaySettings(display);
        const tz =
          typeof data.display_timezone === 'string' && data.display_timezone.trim() !== ''
            ? data.display_timezone.trim()
            : 'America/New_York';
        const historyDepth =
          typeof data.display_program_history_depth === 'number' &&
          Number.isFinite(data.display_program_history_depth)
            ? data.display_program_history_depth
            : CURATOR_HISTORY_DEPTH.default;
        const reservePct = (raw: unknown) =>
          typeof raw === 'number' && Number.isFinite(raw) ? raw : VIEWPORT_RESERVE_PCT.default;
        const tickerDuration =
          typeof data.display_ticker_program_duration_seconds === 'number' &&
          Number.isFinite(data.display_ticker_program_duration_seconds)
            ? data.display_ticker_program_duration_seconds
            : CURATOR_TICKER_PROGRAM_DURATION.default;
        const tickerPx =
          typeof data.display_ticker_pixels_per_second === 'number' &&
          Number.isFinite(data.display_ticker_pixels_per_second)
            ? data.display_ticker_pixels_per_second
            : CURATOR_TICKER_PIXELS_PER_SECOND.default;
        setForm({
          ...data,
          display_timezone: tz,
          display_weather_temperature_unit: normalizeDisplayWeatherTemperatureUnit(
            data.display_weather_temperature_unit,
          ),
          display_program_history_depth: historyDepth,
          display_viewport_reserve_top_pct: reservePct(data.display_viewport_reserve_top_pct),
          display_viewport_reserve_right_pct: reservePct(data.display_viewport_reserve_right_pct),
          display_viewport_reserve_bottom_pct: reservePct(data.display_viewport_reserve_bottom_pct),
          display_viewport_reserve_left_pct: reservePct(data.display_viewport_reserve_left_pct),
          display_ticker_program_duration_seconds: tickerDuration,
          display_ticker_pixels_per_second: tickerPx,
        });
        setInitialized(true);
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    });
  }, [display, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load, kvWriteTick]);

  const save = useCallback(async () => {
    if (!form) return;
    setError(null);
    setSaved(false);
    try {
      await putDisplaySettings(display, {
        display_theme_id: form.display_theme_id,
        display_program_history_depth: form.display_program_history_depth,
        display_text_scale_screen: form.display_text_scale_screen,
        display_text_scale_ticker: form.display_text_scale_ticker,
        display_timezone: form.display_timezone,
        display_weather_temperature_unit: form.display_weather_temperature_unit,
        controller_time_format: form.controller_time_format,
        controller_date_order: form.controller_date_order,
        display_viewport_reserve_top_pct: form.display_viewport_reserve_top_pct,
        display_viewport_reserve_right_pct: form.display_viewport_reserve_right_pct,
        display_viewport_reserve_bottom_pct: form.display_viewport_reserve_bottom_pct,
        display_viewport_reserve_left_pct: form.display_viewport_reserve_left_pct,
        display_ticker_program_duration_seconds: form.display_ticker_program_duration_seconds,
        display_ticker_pixels_per_second: form.display_ticker_pixels_per_second,
      });
      await refreshFormat();
      setSaved(true);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  }, [display, form, refreshFormat]);

  const deleteCustomTheme = useCallback(
    async (theme: DisplayCustomTheme) => {
      setError(null);
      try {
        await deleteDisplayTheme(display, theme.id);
        onKvChanged();
        setForm((prev) => {
          if (!prev) return prev;
          if (prev.display_theme_id === theme.id) {
            return { ...prev, display_theme_id: 'navy_coral' };
          }
          return prev;
        });
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
        throw e;
      }
    },
    [display, onKvChanged],
  );

  if ((!initialized && loading) || !form) {
    return null;
  }

  const setFormValue: Dispatch<SetStateAction<DisplaySettings>> = (action) => {
    setForm((prev) => {
      if (!prev) return prev;
      return typeof action === 'function' ? action(prev) : action;
    });
  };

  return {
    loading,
    initialized,
    error,
    saved,
    setSaved,
    form,
    setForm: setFormValue,
    save,
    themeOptions,
    timezoneOptions,
    selectedTimezone,
    themeDialogOpen,
    setThemeDialogOpen,
    themeDialogEdit,
    setThemeDialogEdit,
    deleteCustomTheme,
    displayThemeOptionById,
  };
}
