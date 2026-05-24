import { useMemo } from 'react';
import {
  Checkbox,
  FormControl,
  InputLabel,
  ListItemText,
  MenuItem,
  OutlinedInput,
  Select,
  type SelectChangeEvent,
} from '@mui/material';
import {
  resolveCategoryLabels,
  type ContentCategoryOption,
} from '@/util/contentCategorySelect';

export type { ContentCategoryOption };

type Props = {
  id: string;
  label: string;
  value: string[];
  onChange: (labels: string[]) => void;
  categories: ContentCategoryOption[];
  disabled?: boolean;
  size?: 'small' | 'medium';
};

export function CategoryMultiSelect({
  id,
  label,
  value,
  onChange,
  categories,
  disabled = false,
  size = 'small',
}: Props) {
  const selectValue = useMemo(
    () => resolveCategoryLabels(value, categories),
    [value, categories],
  );

  const knownLabels = useMemo(() => new Set(categories.map((c) => c.label)), [categories]);
  const orphanLabels = useMemo(
    () => selectValue.filter((l) => !knownLabels.has(l)),
    [selectValue, knownLabels],
  );

  const handleChange = (e: SelectChangeEvent<string[]>) => {
    const raw = e.target.value;
    onChange(typeof raw === 'string' ? raw.split(',') : raw);
  };

  const renderValue = (selected: string[]) => {
    if (selected.length === 0) {
      return <em>Default</em>;
    }
    return selected.join(', ');
  };

  return (
    <FormControl fullWidth size={size} disabled={disabled}>
      <InputLabel id={id}>{label}</InputLabel>
      <Select
        labelId={id}
        multiple
        value={selectValue}
        onChange={handleChange}
        input={<OutlinedInput label={label} />}
        renderValue={renderValue}
      >
        {orphanLabels.map((name) => (
          <MenuItem key={`orphan-${name}`} value={name}>
            <Checkbox checked={selectValue.includes(name)} size="small" />
            <ListItemText primary={name} />
          </MenuItem>
        ))}
        {categories.map((cat) => (
          <MenuItem key={cat.id} value={cat.label}>
            <Checkbox checked={selectValue.includes(cat.label)} size="small" />
            <ListItemText primary={cat.label} />
          </MenuItem>
        ))}
      </Select>
    </FormControl>
  );
}
