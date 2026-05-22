import { Outlet } from 'react-router-dom';
import { Box } from '@mui/material';

/** Minimal chrome for live-preview pop-out (no AppShell drawer or app bar). */
export function RemoteViewShell() {
  return (
    <Box
      sx={{
        minHeight: '100vh',
        height: '100vh',
        display: 'flex',
        flexDirection: 'column',
        bgcolor: 'background.default',
        overflow: 'hidden',
      }}
    >
      <Outlet />
    </Box>
  );
}
