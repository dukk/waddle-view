import { useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import { Alert, Box, Typography } from '@mui/material';
import { useDisplay } from '@/context/DisplayContext';
import { useAuth } from '@/context/AuthContext';
import { RemoteViewPanel } from '@/components/remote/RemoteViewPanel';
import { loadDisplays } from '@/storage/displays';

export function RemoteViewPage() {
  const [params] = useSearchParams();
  const { active, displays } = useDisplay();
  const { hasPermission } = useAuth();

  const displayId = params.get('displayId') ?? '';
  const ticket = params.get('ticket') ?? '';

  const display = useMemo(() => {
    const fromContext =
      active?.id === displayId
        ? active
        : displays.find((d) => d.id === displayId);
    if (fromContext) return fromContext;
    return loadDisplays().find((d) => d.id === displayId) ?? null;
  }, [active, displayId, displays]);

  if (!hasPermission('navigation.control')) {
    return (
      <Alert severity="warning" sx={{ m: 2 }}>
        Your role does not include remote view access.
      </Alert>
    );
  }

  if (!display) {
    return (
      <Alert severity="warning" sx={{ m: 2 }}>
        Unknown or missing display. Close this window and try again from the controller.
      </Alert>
    );
  }

  if (!ticket) {
    return (
      <Alert severity="warning" sx={{ m: 2 }}>
        Missing session ticket. Open remote view from the controller Remote page or display settings
        test button.
      </Alert>
    );
  }

  return (
    <Box sx={{ height: '100vh', display: 'flex', flexDirection: 'column', p: 1 }}>
      <Typography variant="subtitle2" sx={{ mb: 1 }}>
        Remote view — {display.label}
      </Typography>
      <Box sx={{ flex: 1, minHeight: 0 }}>
        <RemoteViewPanel
          display={display}
          initialTicket={ticket}
          autoConnect
          popOutPath="/remote/view"
        />
      </Box>
    </Box>
  );
}
