import { useCallback, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
  Box,
  Chip,
  CircularProgress,
  Stack,
  Typography,
} from '@mui/material';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import { createLivePreviewSession } from '@/api/displayLivePreview';
import { CompactDisplayPicker } from '@/components/remote/CompactDisplayPicker';
import {
  LivePreviewPanel,
  type LivePreviewConnectionStatus,
} from '@/components/remote/LivePreviewPanel';
import { RemoteControlsPanel } from '@/components/remote/RemoteControlsPanel';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { useDisplayRemoteShortcuts } from '@/hooks/useDisplayRemoteShortcuts';
import { usePersistLivePreviewPopOutBounds } from '@/hooks/usePersistLivePreviewPopOutBounds';
import { loadDisplays } from '@/storage/displays';

function connectionChipLabel(status: LivePreviewConnectionStatus): string {
  switch (status) {
    case 'connected':
      return 'Connected';
    case 'connecting':
      return 'Connecting…';
    case 'error':
      return 'Error';
    default:
      return 'Disconnected';
  }
}

function connectionChipColor(
  status: LivePreviewConnectionStatus,
): 'success' | 'warning' | 'error' | 'default' {
  switch (status) {
    case 'connected':
      return 'success';
    case 'connecting':
      return 'warning';
    case 'error':
      return 'error';
    default:
      return 'default';
  }
}

export function RemoteViewPage() {
  usePersistLivePreviewPopOutBounds();

  const [params, setSearchParams] = useSearchParams();
  const { active, displays, setActiveId } = useDisplay();
  const { hasPermission } = useAuth();
  const [connectionStatus, setConnectionStatus] =
    useState<LivePreviewConnectionStatus>('idle');
  const [displaySwitchBusy, setDisplaySwitchBusy] = useState(false);
  const [displaySwitchError, setDisplaySwitchError] = useState<string | null>(null);

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

  const { snack: shortcutSnack, clearSnack: clearShortcutSnack } = useDisplayRemoteShortcuts(
    display,
    hasPermission,
  );

  useEffect(() => {
    if (displayId && display && active?.id !== displayId) {
      setActiveId(displayId);
    }
  }, [displayId, display, active?.id, setActiveId]);

  useEffect(() => {
    if (display) {
      document.title = `Live preview — ${display.label}`;
    }
    return () => {
      document.title = 'Waddle Controller';
    };
  }, [display]);

  const handleDisplaySelect = useCallback(
    async (id: string) => {
      if (id === display?.id) return;
      const next = displays.find((d) => d.id === id) ?? loadDisplays().find((d) => d.id === id);
      if (!next) return;
      setDisplaySwitchBusy(true);
      setDisplaySwitchError(null);
      setActiveId(id);
      try {
        const session = await createLivePreviewSession(next);
        setSearchParams({ displayId: id, ticket: session.ticket });
      } catch (e) {
        setDisplaySwitchError(String(e));
      } finally {
        setDisplaySwitchBusy(false);
      }
    },
    [display?.id, displays, setActiveId, setSearchParams],
  );

  if (!hasPermission('navigation.control')) {
    return (
      <Alert severity="warning" sx={{ m: 2 }}>
        Your role does not include live preview access.
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
        Missing session ticket. Open live preview from the controller Remote page or display
        settings test button.
      </Alert>
    );
  }

  const canDismissAlerts = hasPermission('alerts.write');

  return (
    <Box
      sx={{
        flex: 1,
        minHeight: 0,
        display: 'flex',
        flexDirection: 'column',
        p: 1.5,
        gap: 1,
        overflow: 'hidden',
      }}
    >
      <Stack
        direction="row"
        spacing={1}
        sx={{
          alignItems: "center",
          flexWrap: "wrap",
          flexShrink: 0
        }}>
        <CompactDisplayPicker
          displays={displays}
          active={display}
          onSelect={(id) => void handleDisplaySelect(id)}
          disabled={displaySwitchBusy}
        />
        <Chip
          size="small"
          label={connectionChipLabel(connectionStatus)}
          color={connectionChipColor(connectionStatus)}
          variant="outlined"
        />
        {displaySwitchBusy && <CircularProgress size={20} />}
      </Stack>
      {displaySwitchError && (
        <Alert severity="error" onClose={() => setDisplaySwitchError(null)} sx={{ flexShrink: 0 }}>
          {displaySwitchError}
        </Alert>
      )}
      <Box
        sx={{
          flex: 1,
          minHeight: 0,
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
        }}
      >
        <LivePreviewPanel
          key={`${display.id}-${ticket}`}
          display={display}
          initialTicket={ticket}
          autoConnect
          showPopOut={false}
          layout="embedded"
          onStatusChange={setConnectionStatus}
        />
      </Box>
      <Accordion sx={{ flexShrink: 0 }}>
        <AccordionSummary expandIcon={<ExpandMoreIcon />}>
          <Typography variant="subtitle2" sx={{
            fontWeight: 600
          }}>
            Remote controls
          </Typography>
        </AccordionSummary>
        <AccordionDetails sx={{ pt: 0 }}>
          <RemoteControlsPanel
            display={display}
            canDismissAlerts={canDismissAlerts}
            variant="compact"
            externalSnack={shortcutSnack}
            onExternalSnackClose={clearShortcutSnack}
          />
        </AccordionDetails>
      </Accordion>
    </Box>
  );
}
