import type { FieldProps } from '@rjsf/utils';
import { Box, FormControl, FormHelperText, InputLabel, MenuItem, Select } from '@mui/material';
import type { DisplayThemePreviewGroups } from '@/constants/displayThemePreview';
import { DisplayThemePaletteSwatches } from '@/components/DisplayThemePaletteSwatches';
import { THEME_ACCENT_OPTIONS } from '@/constants/clockEnumLabels';

type Props = FieldProps & {
  themePreview?: DisplayThemePreviewGroups;
};

function readAccentValue(formData: unknown): string {
  if (typeof formData === 'string' && formData.trim()) {
    return formData.trim();
  }
  if (typeof formData === 'number' && formData >= 1 && formData <= 3) {
    return String(formData);
  }
  return 'accent1';
}

function accentHex(preview: DisplayThemePreviewGroups | undefined, accentIndex: number): string | undefined {
  const accents = preview?.accents;
  if (!accents || accentIndex < 0 || accentIndex >= accents.length) {
    return undefined;
  }
  return accents[accentIndex];
}

export function ThemeAccentSelectField(props: Props) {
  const { formData, onChange, disabled, schema, rawErrors, themePreview } = props;
  const value = readAccentValue(formData);
  const label = (schema.title as string | undefined) ?? 'Hand accent';
  const fieldId = schema.$id != null ? String(schema.$id) : 'theme-accent';

  return (
    <FormControl fullWidth error={rawErrors != null && rawErrors.length > 0} disabled={disabled}>
      <InputLabel id={`${fieldId}-label`}>{label}</InputLabel>
      <Select
        labelId={`${fieldId}-label`}
        label={label}
        value={value}
        onChange={(e) => {
          const next = String(e.target.value);
          onChange(next);
        }}
      >
        {THEME_ACCENT_OPTIONS.map((o) => {
          const hex = accentHex(themePreview, o.accentIndex);
          return (
            <MenuItem key={`${fieldId}-${o.value}`} value={o.value}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, width: '100%' }}>
                <span>{o.label}</span>
                {hex ? (
                  <DisplayThemePaletteSwatches colors={[hex]} size={16} />
                ) : null}
              </Box>
            </MenuItem>
          );
        })}
      </Select>
      {rawErrors?.length ? (
        <FormHelperText>{rawErrors.join(', ')}</FormHelperText>
      ) : schema.description ? (
        <FormHelperText>{String(schema.description)}</FormHelperText>
      ) : null}
    </FormControl>
  );
}
