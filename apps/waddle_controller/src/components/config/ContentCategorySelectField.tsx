import { useMemo } from 'react';
import type { FieldProps } from '@rjsf/utils';
import { FormControl, FormHelperText, InputLabel, MenuItem, Select } from '@mui/material';
import {
  resolveCategoryLabel,
  type ContentCategoryOption,
} from '@/util/contentCategorySelect';

export type { ContentCategoryOption };

type StandaloneProps = {
  id: string;
  label: string;
  value: string;
  onChange: (category: string) => void;
  categories: ContentCategoryOption[];
  disabled?: boolean;
};

type Props = FieldProps & {
  categories: ContentCategoryOption[];
};

function readCategoryStored(formData: unknown): string {
  return typeof formData === 'string' ? formData : '';
}

function CategorySelectMenuItems({
  categories,
  selectValue,
}: {
  categories: ContentCategoryOption[];
  selectValue: string;
}) {
  const knownLabels = new Set(categories.map((c) => c.label));
  const showOrphan = selectValue && !knownLabels.has(selectValue);

  return (
    <>
      <MenuItem value="">
        <em>None</em>
      </MenuItem>
      {showOrphan ? (
        <MenuItem key={`orphan-${selectValue}`} value={selectValue}>
          {selectValue}
        </MenuItem>
      ) : null}
      {categories.map((cat) => (
        <MenuItem key={cat.id} value={cat.label}>
          {cat.label}
        </MenuItem>
      ))}
    </>
  );
}

export function ContentCategorySelect({
  id,
  label,
  value,
  onChange,
  categories,
  disabled,
}: StandaloneProps) {
  const selectValue = useMemo(
    () => resolveCategoryLabel(value, categories),
    [value, categories],
  );

  return (
    <FormControl fullWidth disabled={disabled}>
      <InputLabel id={`${id}-label`}>{label}</InputLabel>
      <Select
        labelId={`${id}-label`}
        label={label}
        value={selectValue}
        onChange={(e) => onChange(String(e.target.value))}
      >
        <CategorySelectMenuItems categories={categories} selectValue={selectValue} />
      </Select>
    </FormControl>
  );
}

export function ContentCategorySelectField(props: Props) {
  const { categories, formData, onChange, disabled, schema, rawErrors } = props;
  const stored = readCategoryStored(formData);
  const selectValue = useMemo(
    () => resolveCategoryLabel(stored, categories),
    [stored, categories],
  );
  const label = (schema.title as string | undefined) ?? 'Category';
  const fieldId = schema.$id != null ? String(schema.$id) : 'content-category';

  return (
    <FormControl fullWidth error={rawErrors != null && rawErrors.length > 0} disabled={disabled}>
      <InputLabel id={`${fieldId}-label`}>{label}</InputLabel>
      <Select
        labelId={`${fieldId}-label`}
        label={label}
        value={selectValue}
        onChange={(e) => {
          const next = String(e.target.value);
          onChange(next === '' ? undefined : next);
        }}
      >
        <CategorySelectMenuItems categories={categories} selectValue={selectValue} />
      </Select>
      {rawErrors?.length ? (
        <FormHelperText>{rawErrors.join(', ')}</FormHelperText>
      ) : schema.description ? (
        <FormHelperText>{String(schema.description)}</FormHelperText>
      ) : null}
    </FormControl>
  );
}
