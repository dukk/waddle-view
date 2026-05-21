import { Typography } from '@mui/material';

type Props = {
  emptyMessage?: string;
  noMatchesMessage?: string;
  hasItems: boolean;
  hasFilteredMatches: boolean;
};

export function DataViewEmptyState({
  emptyMessage = 'No items yet.',
  noMatchesMessage = 'No rows match the current filters.',
  hasItems,
  hasFilteredMatches,
}: Props) {
  if (hasFilteredMatches) return null;
  return (
    <Typography variant="body2" color="text.secondary">
      {hasItems ? noMatchesMessage : emptyMessage}
    </Typography>
  );
}
