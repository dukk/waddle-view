import { useEffect, useMemo, useState } from 'react';
import type { FieldProps } from '@rjsf/utils';
import { Autocomplete, CircularProgress, TextField } from '@mui/material';
import { listStockSymbols, type StockSymbolRow } from '@/api/interests';
import type { SavedDisplay } from '@/storage/displays';

type Props = FieldProps & {
  display: SavedDisplay;
};

function readSymbols(formData: unknown): string[] {
  if (!Array.isArray(formData)) {
    return [];
  }
  return formData
    .filter((x): x is string => typeof x === 'string' && x.trim() !== '')
    .map((s) => s.trim().toUpperCase());
}

function symbolLabel(row: StockSymbolRow): string {
  const name = row.display_name?.trim();
  return name ? `${row.symbol} — ${name}` : row.symbol;
}

export function StockSymbolsMultiSelectField(props: Props) {
  const { display, formData, onChange, disabled, schema, rawErrors } = props;
  const selected = readSymbols(formData);
  const label = (schema.title as string | undefined) ?? 'Stock symbols';
  const [rows, setRows] = useState<StockSymbolRow[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    void listStockSymbols(display)
      .then((items) => {
        if (!cancelled) {
          setRows(
            [...items]
              .filter((s) => s.enabled)
              .sort((a, b) => a.symbol.localeCompare(b.symbol)),
          );
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [display]);

  const options = useMemo(() => rows.map((r) => r.symbol.toUpperCase()), [rows]);
  const labelBySymbol = useMemo(() => {
    const m = new Map<string, string>();
    for (const r of rows) {
      m.set(r.symbol.toUpperCase(), symbolLabel(r));
    }
    return m;
  }, [rows]);

  if (loading) {
    return <CircularProgress size={24} />;
  }

  return (
    <Autocomplete
      multiple
      fullWidth
      disabled={disabled}
      options={options}
      value={selected}
      onChange={(_, next) => onChange(next.length === 0 ? undefined : next)}
      getOptionLabel={(sym) => labelBySymbol.get(sym) ?? sym}
      isOptionEqualToValue={(a, b) => a === b}
      renderInput={(params) => (
        <TextField
          {...params}
          label={label}
          error={rawErrors != null && rawErrors.length > 0}
          helperText={
            rawErrors?.length
              ? rawErrors.join(', ')
              : typeof schema.description === 'string'
                ? schema.description
                : 'Leave empty to show all enabled symbols.'
          }
        />
      )}
    />
  );
}
