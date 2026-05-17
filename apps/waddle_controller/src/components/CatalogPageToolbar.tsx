import { Stack } from '@mui/material';
import type { ReactNode } from 'react';
import { ListLayoutToggle } from '@/components/ListLayoutToggle';
import type { ListLayoutMode } from '@/storage/listLayoutPreference';

type Props = {
  layout: ListLayoutMode;
  onLayoutChange: (value: ListLayoutMode) => void;
  children?: ReactNode;
};

export function CatalogPageToolbar({ layout, onLayoutChange, children }: Props) {
  return (
    <Stack direction="row" justifyContent="flex-end" alignItems="center" flexWrap="wrap" gap={1}>
      <ListLayoutToggle value={layout} onChange={onLayoutChange} />
      {children}
    </Stack>
  );
}
