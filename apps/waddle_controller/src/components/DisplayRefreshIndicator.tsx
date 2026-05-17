import { Box, LinearProgress } from '@mui/material';

type Props = {
  loading: boolean;
};

/** Thin progress bar shown while a page is fetching from the active display. */
export function DisplayRefreshIndicator({ loading }: Props) {
  return (
    <Box
      sx={{
        height: loading ? 4 : 0,
        overflow: 'hidden',
        transition: 'height 0.15s ease',
      }}
      aria-hidden={!loading}
    >
      <LinearProgress aria-label="Refreshing from display" />
    </Box>
  );
}
