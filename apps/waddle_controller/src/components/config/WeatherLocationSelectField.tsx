import { useEffect, useState } from 'react';
import type { FieldProps } from '@rjsf/utils';
import {
  CircularProgress,
  FormControl,
  FormHelperText,
  InputLabel,
  MenuItem,
  Select,
} from '@mui/material';
import { listWeatherLocations } from '@/api/interests';
import type { SavedDisplay } from '@/storage/displays';

type Props = FieldProps & {
  display: SavedDisplay;
};

function readLocationName(formData: unknown): string {
  return typeof formData === 'string' ? formData : '';
}

export function WeatherLocationSelectField(props: Props) {
  const { display, formData, onChange, disabled, schema, rawErrors } = props;
  const value = readLocationName(formData);
  const label = (schema.title as string | undefined) ?? 'Location';
  const fieldId = schema.$id != null ? String(schema.$id) : 'weather-location';
  const [locations, setLocations] = useState<{ name: string }[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    void listWeatherLocations(display)
      .then((items) => {
        if (!cancelled) {
          setLocations(
            [...items]
              .filter((l) => l.include_weather)
              .map((l) => ({ name: l.name.trim() }))
              .filter((l) => l.name.length > 0)
              .sort((a, b) => a.name.localeCompare(b.name)),
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

  if (loading) {
    return <CircularProgress size={24} />;
  }

  return (
    <FormControl fullWidth error={rawErrors != null && rawErrors.length > 0} disabled={disabled}>
      <InputLabel id={`${fieldId}-label`}>{label}</InputLabel>
      <Select
        labelId={`${fieldId}-label`}
        label={label}
        value={value}
        onChange={(e) => {
          const next = String(e.target.value);
          onChange(next === '' ? undefined : next);
        }}
      >
        {locations.map((l) => (
          <MenuItem key={l.name} value={l.name}>
            {l.name}
          </MenuItem>
        ))}
      </Select>
      {rawErrors?.length ? (
        <FormHelperText>{rawErrors.join(', ')}</FormHelperText>
      ) : schema.description ? (
        <FormHelperText>{String(schema.description)}</FormHelperText>
      ) : null}
    </FormControl>
  );
}
