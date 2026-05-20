import { useEffect, useState } from 'react';
import {
  CircularProgress,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Typography,
} from '@mui/material';
import { listStockSymbols, type StockSymbolRow } from '@/api/interests';
import type { SavedDisplay } from '@/storage/displays';
import { ClockOverlayPlacementFields } from './ClockOverlayPlacementFields';

type Props = {
  display: SavedDisplay;
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

function readString(raw: unknown, fallback = ''): string {
  return typeof raw === 'string' && raw.trim() ? raw.trim() : fallback;
}

function symbolLabel(row: StockSymbolRow): string {
  const name = row.display_name?.trim();
  return name ? `${row.symbol} — ${name}` : row.symbol;
}

export function StockQuoteOverlayConfigForm({
  display,
  formData,
  onChange,
  disabled,
}: Props) {
  const [symbols, setSymbols] = useState<StockSymbolRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const symbolId = readString(formData.symbolId);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setLoadError(null);
    void listStockSymbols(display)
      .then((items) => {
        if (!cancelled) {
          setSymbols(
            [...items].sort((a, b) => a.symbol.localeCompare(b.symbol)),
          );
        }
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          setLoadError(err instanceof Error ? err.message : 'Failed to load symbols');
          setSymbols([]);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [display]);

  const patch = (partial: Record<string, unknown>) => {
    onChange({ ...formData, ...partial });
  };

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Single stock quote tile at a viewport position. Matches the stock quotes screen;
        requires stock_finnhub to collect quotes.
      </Typography>
      {loading ? (
        <CircularProgress size={24} />
      ) : loadError ? (
        <Typography variant="body2" color="error">
          {loadError}
        </Typography>
      ) : (
        <FormControl fullWidth size="small" required disabled={disabled}>
          <InputLabel id="stock-quote-overlay-symbol">Stock symbol</InputLabel>
          <Select
            labelId="stock-quote-overlay-symbol"
            label="Stock symbol"
            value={symbolId}
            onChange={(e) => {
              patch({ symbolId: e.target.value });
            }}
          >
            {symbols.map((row) => (
              <MenuItem key={row.id} value={row.id}>
                {symbolLabel(row)}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      )}
      {!loading && !loadError && symbols.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          Add stock symbols under Interests → Stocks first.
        </Typography>
      ) : null}
      <ClockOverlayPlacementFields
        formData={formData}
        onChange={onChange}
        disabled={disabled}
        scaleHelp="Tile width as a fraction of the viewport shortest side."
      />
    </Stack>
  );
}
