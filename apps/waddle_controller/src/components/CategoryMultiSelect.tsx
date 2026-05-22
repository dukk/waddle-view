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
export type ContentCategoryOption = {
  id: string;
  label: string;
};

type Props = {
  id: string;
  label: string;
  value: string[];
  onChange: (ids: string[]) => void;
  categories: ContentCategoryOption[];
  disabled?: boolean;
  size?: 'small' | 'medium';
};

function categoryLabel(categories: ContentCategoryOption[], name: string): string {
  return categories.find((c) => c.label === name)?.label ?? name;
}

export function CategoryMultiSelect({
  id,
  label,
  value,
  onChange,
  categories,
  disabled = false,
  size = 'small',
}: Props) {
  const handleChange = (e: SelectChangeEvent<string[]>) => {
    const raw = e.target.value;
    onChange(typeof raw === 'string' ? raw.split(',') : raw);
  };

  const renderValue = (selected: string[]) => {
    if (selected.length === 0) {
      return <em>Default</em>;
    }
    return selected.map((name) => categoryLabel(categories, name)).join(', ');
  };

  return (
    <FormControl fullWidth size={size} disabled={disabled}>
      <InputLabel id={id}>{label}</InputLabel>
      <Select
        labelId={id}
        multiple
        value={value}
        onChange={handleChange}
        input={<OutlinedInput label={label} />}
        renderValue={renderValue}
      >
        {categories.map((cat) => (
          <MenuItem key={cat.id} value={cat.label}>
            <Checkbox checked={value.includes(cat.label)} size="small" />
            <ListItemText primary={cat.label} />
          </MenuItem>
        ))}
      </Select>
    </FormControl>
  );
}
