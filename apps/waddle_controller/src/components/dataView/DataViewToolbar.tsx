import RefreshIcon from '@mui/icons-material/Refresh';
import {
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Tooltip,
} from '@mui/material';
import type { ReactNode } from 'react';
import { ListLayoutToggle } from '@/components/ListLayoutToggle';
import type { ListLayoutMode } from '@/storage/listLayoutPreference';
import type { ServerSortOrder } from '@/hooks/useServerDataView';

export type DataViewSortOption = {
  id: string;
  label: string;
};

type Props = {
  layout: ListLayoutMode;
  onLayoutChange: (value: ListLayoutMode) => void;
  search?: string;
  onSearchChange?: (value: string) => void;
  searchPlaceholder?: string;
  sortOptions?: readonly DataViewSortOption[];
  sortId?: string;
  onSortChange?: (sortId: string) => void;
  order?: ServerSortOrder;
  onOrderChange?: (order: ServerSortOrder) => void;
  onReload?: () => void;
  reloadDisabled?: boolean;
  reloadAriaLabel?: string;
  filterSlot?: ReactNode;
  children?: ReactNode;
};

export function DataViewToolbar({
  layout,
  onLayoutChange,
  search,
  onSearchChange,
  searchPlaceholder = 'Search…',
  sortOptions,
  sortId,
  onSortChange,
  order,
  onOrderChange,
  onReload,
  reloadDisabled = false,
  reloadAriaLabel = 'Reload',
  filterSlot,
  children,
}: Props) {
  const showSearch = onSearchChange != null;
  const showSort =
    sortOptions != null && sortOptions.length > 0 && sortId != null && onSortChange != null;
  const showOrder = onOrderChange != null && order != null;

  return (
    <Stack
      direction="row"
      flexWrap="wrap"
      alignItems="center"
      justifyContent="flex-end"
      gap={1}
      sx={{ width: '100%' }}
    >
      {showSearch ? (
        <TextField
          size="small"
          placeholder={searchPlaceholder}
          value={search ?? ''}
          onChange={(e) => onSearchChange(e.target.value)}
          sx={{ minWidth: 160, flex: { xs: '1 1 100%', sm: '1 1 200px' }, maxWidth: 320 }}
        />
      ) : null}
      {filterSlot}
      {showSort ? (
        <FormControl size="small" sx={{ minWidth: 140 }}>
          <InputLabel id="data-view-sort-label">Sort</InputLabel>
          <Select
            labelId="data-view-sort-label"
            label="Sort"
            value={sortId}
            onChange={(e) => onSortChange(e.target.value)}
          >
            {sortOptions.map((o) => (
              <MenuItem key={o.id} value={o.id}>
                {o.label}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      ) : null}
      {showOrder ? (
        <FormControl size="small" sx={{ minWidth: 120 }}>
          <InputLabel id="data-view-order-label">Order</InputLabel>
          <Select
            labelId="data-view-order-label"
            label="Order"
            value={order}
            onChange={(e) => onOrderChange(e.target.value as ServerSortOrder)}
          >
            <MenuItem value="asc">Ascending</MenuItem>
            <MenuItem value="desc">Descending</MenuItem>
          </Select>
        </FormControl>
      ) : null}
      {onReload ? (
        <Tooltip title={reloadAriaLabel}>
          <span>
            <IconButton
              onClick={() => void onReload()}
              disabled={reloadDisabled}
              aria-label={reloadAriaLabel}
              size="small"
            >
              <RefreshIcon fontSize="small" />
            </IconButton>
          </span>
        </Tooltip>
      ) : null}
      <ListLayoutToggle value={layout} onChange={onLayoutChange} />
      {children}
    </Stack>
  );
}
