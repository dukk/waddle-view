import { Alert, Box } from '@mui/material';

export function NoDisplayPlaceholder() {
  return (
    <Box sx={{ maxWidth: 720 }}>
      <Alert severity="warning">
        No display is adopted yet. Open <strong>Displays</strong> to pair with a display.
      </Alert>
    </Box>
  );
}
