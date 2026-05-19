import type { FieldProps } from '@rjsf/utils';
import { FormControl, FormHelperText, InputLabel, MenuItem, Select } from '@mui/material';

export type ContentCategoryOption = {
  id: string;
  label: string;
};

type Props = FieldProps & {
  categories: ContentCategoryOption[];
};

function readCategoryId(formData: unknown): string {
  return typeof formData === 'string' ? formData : '';
}

export function ContentCategorySelectField(props: Props) {
  const { categories, formData, onChange, disabled, schema, rawErrors } = props;
  const value = readCategoryId(formData);
  const label = (schema.title as string | undefined) ?? 'Category';
  const fieldId = schema.$id != null ? String(schema.$id) : 'content-category';

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
        <MenuItem value="">
          <em>None</em>
        </MenuItem>
        {categories.map((cat) => (
          <MenuItem key={cat.id} value={cat.id}>
            {cat.label}
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
