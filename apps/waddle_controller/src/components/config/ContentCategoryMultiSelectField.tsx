import type { FieldProps } from '@rjsf/utils';
import {
  ContentCategoryOption,
} from '@/components/config/ContentCategorySelectField';
import { CategoryMultiSelect } from '@/components/CategoryMultiSelect';

type Props = FieldProps & {
  categories: ContentCategoryOption[];
};

function readCategoryNames(formData: unknown): string[] {
  if (!Array.isArray(formData)) {
    return [];
  }
  return formData.filter((x): x is string => typeof x === 'string' && x.trim() !== '');
}

export function ContentCategoryMultiSelectField(props: Props) {
  const { categories, formData, onChange, path, disabled, schema, rawErrors: _rawErrors } = props;
  const value = readCategoryNames(formData);
  const label = (schema.title as string | undefined) ?? 'Categories';
  const fieldId = schema.$id != null ? String(schema.$id) : 'content-category-multi';

  return (
    <CategoryMultiSelect
      id={`${fieldId}-label`}
      label={label}
      value={value}
      onChange={(next) => onChange(next.length === 0 ? undefined : next, path)}
      categories={categories}
      disabled={disabled}
      size="medium"
    />
  );
}
