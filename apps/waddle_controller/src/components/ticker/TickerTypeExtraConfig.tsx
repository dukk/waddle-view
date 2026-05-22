import { useEffect, useState } from 'react';
import {
  CircularProgress,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Switch,
  TextField,
  Typography,
} from '@mui/material';
import { listStockSymbols, listWeatherLocations, type StockSymbolRow } from '@/api/interests';
import type { ContentCategoryOption } from '@/components/config/ContentCategorySelectField';
import { ContentCategorySelect } from '@/components/config/ContentCategorySelectField';
import type { SavedDisplay } from '@/storage/displays';

const TIME_FORMAT_PRESETS = [
  { value: '24h_hms', label: '24-hour with seconds (14:05:09)' },
  { value: '24h_hm', label: '24-hour (14:05)' },
  { value: '12h_hms_ampm', label: '12-hour with seconds (2:05:09 PM)' },
  { value: '12h_hm_ampm', label: '12-hour (2:05 PM)' },
  { value: '12h_hm_tt', label: '12-hour compact (2:05pm)' },
] as const;

type Props = {
  display: SavedDisplay;
  tickerType: string;
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
  categories?: ContentCategoryOption[];
};

function readString(raw: unknown, fallback = ''): string {
  return typeof raw === 'string' && raw.trim() ? raw.trim() : fallback;
}

function readBool(raw: unknown): boolean | undefined {
  if (typeof raw === 'boolean') return raw;
  return undefined;
}

function readStringArray(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter((x): x is string => typeof x === 'string' && x.trim() !== '');
}

function symbolLabel(row: StockSymbolRow): string {
  const name = row.display_name?.trim();
  return name ? `${row.symbol} — ${name}` : row.symbol;
}

export function TickerTypeExtraConfig({
  display,
  tickerType,
  formData,
  onChange,
  disabled,
  categories = [],
}: Props) {
  const type = tickerType.trim().toLowerCase();

  const [weatherLocations, setWeatherLocations] = useState<
    { id: string; name: string }[]
  >([]);
  const [weatherLoading, setWeatherLoading] = useState(false);
  const [symbols, setSymbols] = useState<StockSymbolRow[]>([]);
  const [symbolsLoading, setSymbolsLoading] = useState(false);

  useEffect(() => {
    if (type !== 'weather') return;
    let cancelled = false;
    setWeatherLoading(true);
    void listWeatherLocations(display)
      .then((items) => {
        if (!cancelled) {
          setWeatherLocations(
            [...items]
              .filter((l) => l.include_weather)
              .map((l) => ({ id: l.id, name: l.name }))
              .sort((a, b) => a.name.localeCompare(b.name)),
          );
        }
      })
      .finally(() => {
        if (!cancelled) setWeatherLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [display, type]);

  useEffect(() => {
    if (type !== 'stocks') return;
    let cancelled = false;
    setSymbolsLoading(true);
    void listStockSymbols(display)
      .then((items) => {
        if (!cancelled) {
          setSymbols(
            [...items]
              .filter((s) => s.enabled)
              .sort((a, b) => a.symbol.localeCompare(b.symbol)),
          );
        }
      })
      .finally(() => {
        if (!cancelled) setSymbolsLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [display, type]);

  const patch = (partial: Record<string, unknown>) => {
    onChange({ ...formData, ...partial });
  };

  if (type === 'time') {
    const preset = readString(formData.timeFormatPreset, '24h_hms');
    return (
      <Stack spacing={1.5}>
        <FormControl fullWidth disabled={disabled}>
          <InputLabel id="ticker-time-preset">Time format</InputLabel>
          <Select
            labelId="ticker-time-preset"
            label="Time format"
            value={preset}
            onChange={(e) => patch({ timeFormatPreset: e.target.value })}
          >
            {TIME_FORMAT_PRESETS.map((o) => (
              <MenuItem key={o.value} value={o.value}>
                {o.label}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        <TextField
          label="Time zone (IANA, optional)"
          value={readString(formData.timeZone)}
          onChange={(e) => patch({ timeZone: e.target.value })}
          disabled={disabled}
          fullWidth
          placeholder="America/Chicago"
          helperText="Leave empty for device local time."
        />
        <TextField
          label="Label prefix (optional)"
          value={readString(formData.labelPrefix)}
          onChange={(e) => patch({ labelPrefix: e.target.value })}
          disabled={disabled}
          fullWidth
          placeholder="NYC"
        />
      </Stack>
    );
  }

  if (type === 'weather') {
    const locationId = readString(formData.locationId);
    const unit = readString(formData.temperatureUnit);
    return (
      <Stack spacing={1.5}>
        {weatherLoading ? (
          <CircularProgress size={24} />
        ) : (
          <FormControl fullWidth disabled={disabled}>
            <InputLabel id="ticker-weather-location">Weather location</InputLabel>
            <Select
              labelId="ticker-weather-location"
              label="Weather location"
              value={locationId}
              onChange={(e) => patch({ locationId: e.target.value })}
            >
              <MenuItem value="">
                <em>First location with data</em>
              </MenuItem>
              {weatherLocations.map((l) => (
                <MenuItem key={l.id} value={l.id}>
                  {l.name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        )}
        <FormControl fullWidth disabled={disabled}>
          <InputLabel id="ticker-weather-unit">Temperature unit</InputLabel>
          <Select
            labelId="ticker-weather-unit"
            label="Temperature unit"
            value={unit}
            onChange={(e) => patch({ temperatureUnit: e.target.value })}
          >
            <MenuItem value="">
              <em>Use display default</em>
            </MenuItem>
            <MenuItem value="c">Celsius (°C)</MenuItem>
            <MenuItem value="f">Fahrenheit (°F)</MenuItem>
          </Select>
        </FormControl>
      </Stack>
    );
  }

  if (type === 'news') {
    const prefix = readBool(formData.prefixFeedName);
    return (
      <Stack spacing={1.5}>
        <ContentCategorySelect
          id="ticker-news-category"
          label="News category (optional)"
          value={readString(formData.categoryId)}
          onChange={(categoryId) =>
            patch({ categoryId: categoryId || undefined })
          }
          categories={categories}
          disabled={disabled}
        />
        <FormControlLabel
          control={
            <Switch
              checked={prefix ?? true}
              onChange={(_, checked) => patch({ prefixFeedName: checked })}
              disabled={disabled}
            />
          }
          label="Prefix headlines with feed name"
        />
        <Typography variant="caption" color="text.secondary">
          Leave category empty for all RSS feeds. Turn off prefix to show title only.
        </Typography>
      </Stack>
    );
  }

  if (type === 'stocks') {
    const selected = readStringArray(formData.symbolIds);
    return (
      <Stack spacing={1.5}>
        {symbolsLoading ? (
          <CircularProgress size={24} />
        ) : (
          <FormControl fullWidth disabled={disabled}>
            <InputLabel id="ticker-stock-symbols">Stock symbols</InputLabel>
            <Select
              labelId="ticker-stock-symbols"
              label="Stock symbols"
              multiple
              value={selected}
              onChange={(e) => {
                const v = e.target.value;
                patch({
                  symbolIds: typeof v === 'string' ? v.split(',') : v,
                });
              }}
              renderValue={(ids) =>
                ids.length === 0
                  ? 'All enabled symbols'
                  : ids
                      .map((id) => symbols.find((s) => s.id === id))
                      .filter(Boolean)
                      .map((s) => symbolLabel(s!))
                      .join(', ')
              }
            >
              {symbols.map((s) => (
                <MenuItem key={s.id} value={s.id}>
                  {symbolLabel(s)}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        )}
        <Typography variant="caption" color="text.secondary">
          Select none to show all enabled symbols from Interests → Stocks.
        </Typography>
      </Stack>
    );
  }

  return null;
}
