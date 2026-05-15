import { Alert, Box } from '@mui/material';

export function NoDisplayPlaceholder() {
  return (
    <Box sx={{ maxWidth: 720 }}>
      <Alert severity="warning">
        No display is configured. Use <strong>Settings</strong> (or complete the first-run dialog)
        to add a base URL and API key.
      </Alert>
    </Box>
  );
}
