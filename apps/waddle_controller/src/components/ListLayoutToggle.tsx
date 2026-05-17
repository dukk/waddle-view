import ViewModuleOutlinedIcon from '@mui/icons-material/ViewModuleOutlined';
import TableRowsOutlinedIcon from '@mui/icons-material/TableRowsOutlined';
import { ToggleButton, ToggleButtonGroup, Tooltip } from '@mui/material';
import type { ListLayoutMode } from '@/storage/listLayoutPreference';

type Props = {
  value: ListLayoutMode;
  onChange: (value: ListLayoutMode) => void;
};

export function ListLayoutToggle({ value, onChange }: Props) {
  return (
    <ToggleButtonGroup
      exclusive
      size="small"
      value={value}
      onChange={(_, next: ListLayoutMode | null) => {
        if (next != null) onChange(next);
      }}
      aria-label="List layout"
    >
      <Tooltip title="Card view">
        <ToggleButton value="card" aria-label="Card view">
          <ViewModuleOutlinedIcon fontSize="small" />
        </ToggleButton>
      </Tooltip>
      <Tooltip title="Table view">
        <ToggleButton value="table" aria-label="Table view">
          <TableRowsOutlinedIcon fontSize="small" />
        </ToggleButton>
      </Tooltip>
    </ToggleButtonGroup>
  );
}
