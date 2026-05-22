import { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, Box, Button, CircularProgress, Stack, Typography } from '@mui/material';
import DesktopWindowsIcon from '@mui/icons-material/DesktopWindows';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import RFB from '@novnc/novnc';
import { createRemoteViewSession } from '@/api/displayRemoteView';
import type { SavedDisplay } from '@/storage/displays';
import {
  buildRemoteViewWebSocketUrl,
  consumeRemoteViewTestPayload,
} from '@/util/remoteViewWsUrl';

type Props = {
  display: SavedDisplay;
  /** When set, opens pop-out instead of inline connect on mount. */
  popOutPath?: string;
  onDisconnect?: () => void;
  /** Pre-created ticket (pop-out / test flow). */
  initialTicket?: string;
  /** VNC password for test flow or when operator supplied. */
  vncPassword?: string;
  passwordConfigured?: boolean;
  /** When true, connects on mount (pop-out with a pre-issued ticket). */
  autoConnect?: boolean;
};

export function RemoteViewPanel({
  display,
  popOutPath = '/remote/view',
  onDisconnect,
  initialTicket,
  vncPassword,
  passwordConfigured,
  autoConnect = false,
}: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const rfbRef = useRef<RFB | null>(null);
  const [status, setStatus] = useState<'idle' | 'connecting' | 'connected' | 'error'>('idle');
  const [error, setError] = useState<string | null>(null);
  const [passwordPrompt, setPasswordPrompt] = useState('');

  const disconnect = useCallback(() => {
    rfbRef.current?.disconnect();
    rfbRef.current = null;
    setStatus('idle');
    onDisconnect?.();
  }, [onDisconnect]);

  const connect = useCallback(
    async (ticketOverride?: string) => {
      if (!containerRef.current) return;
      setError(null);
      setStatus('connecting');
      try {
        const testPayload = consumeRemoteViewTestPayload(display.id);
        let ticket = ticketOverride ?? initialTicket ?? testPayload?.ticket;
        if (!ticket) {
          const session = await createRemoteViewSession(display);
          ticket = session.ticket;
        }
        const wsUrl = buildRemoteViewWebSocketUrl(display, ticket, {
          baseUrlOverride: testPayload?.baseUrl,
        });
        const password =
          vncPassword ??
          testPayload?.vncPassword ??
          (passwordPrompt.trim() || undefined);

        rfbRef.current?.disconnect();
        const rfb = new RFB(containerRef.current, wsUrl, {
          credentials: password ? { password } : undefined,
        });
        rfb.scaleViewport = true;
        rfb.resizeSession = true;
        rfb.addEventListener('connect', () => setStatus('connected'));
        rfb.addEventListener('disconnect', () => {
          setStatus('idle');
          onDisconnect?.();
        });
        rfb.addEventListener('securityfailure', () => {
          setStatus('error');
          setError('VNC authentication failed. Check the password and try again.');
        });
        rfbRef.current = rfb;
      } catch (e) {
        setStatus('error');
        setError(String(e));
      }
    },
    [display, initialTicket, onDisconnect, passwordPrompt, vncPassword],
  );

  useEffect(() => {
    if (!autoConnect) return;
    void connect();
    return () => {
      rfbRef.current?.disconnect();
      rfbRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- connect once when panel mounts
  }, []);

  const openPopOut = useCallback(async () => {
    try {
      const session = await createRemoteViewSession(display);
      const params = new URLSearchParams({
        displayId: display.id,
        ticket: session.ticket,
      });
      window.open(`${popOutPath}?${params.toString()}`, '_blank', 'noopener,noreferrer');
    } catch (e) {
      setError(String(e));
      setStatus('error');
    }
  }, [display, popOutPath]);

  const needsPassword =
    passwordConfigured && !vncPassword && !passwordPrompt.trim() && status === 'idle';

  const showPlaceholder = status !== 'connected';

  return (
    <Stack spacing={1} sx={{ height: '100%', minHeight: 320 }}>
      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}
      {needsPassword && (
        <Alert severity="info">
          Enter the VNC password below, then connect. The password is stored on the display, not
          returned over the API.
        </Alert>
      )}
      {needsPassword && (
        <Box>
          <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 0.5 }}>
            VNC password
          </Typography>
          <input
            type="password"
            value={passwordPrompt}
            onChange={(e) => setPasswordPrompt(e.target.value)}
            style={{ width: '100%', padding: 8, fontFamily: 'inherit' }}
            autoComplete="off"
          />
        </Box>
      )}
      <Box
        ref={containerRef}
        sx={{
          flex: 1,
          minHeight: 280,
          bgcolor: 'grey.900',
          borderRadius: 1,
          overflow: 'hidden',
          position: 'relative',
        }}
      >
        {showPlaceholder && (
          <Stack
            alignItems="center"
            justifyContent="center"
            spacing={2}
            sx={{
              position: 'absolute',
              inset: 0,
              zIndex: 1,
              bgcolor: 'grey.900',
              p: 2,
              textAlign: 'center',
            }}
          >
            {status === 'connecting' ? (
              <>
                <CircularProgress color="inherit" />
                <Typography variant="body2" color="grey.400">
                  Connecting to display…
                </Typography>
              </>
            ) : (
              <>
                <DesktopWindowsIcon sx={{ fontSize: 48, color: 'grey.600' }} />
                <Typography variant="body2" color="grey.400">
                  Live display desktop will appear here after you connect.
                </Typography>
                <Stack direction="row" spacing={1} flexWrap="wrap" justifyContent="center">
                  <Button
                    variant="contained"
                    size="small"
                    onClick={() => void connect()}
                  >
                    Connect
                  </Button>
                  <Button
                    variant="outlined"
                    size="small"
                    startIcon={<OpenInNewIcon />}
                    onClick={() => void openPopOut()}
                  >
                    Open in new window
                  </Button>
                </Stack>
              </>
            )}
          </Stack>
        )}
        {status === 'connected' && (
          <Stack
            direction="row"
            spacing={1}
            sx={{
              position: 'absolute',
              top: 8,
              right: 8,
              zIndex: 2,
            }}
          >
            <Button size="small" variant="contained" color="inherit" onClick={disconnect}>
              Disconnect
            </Button>
            <Button
              size="small"
              variant="outlined"
              color="inherit"
              startIcon={<OpenInNewIcon />}
              onClick={() => void openPopOut()}
            >
              Pop out
            </Button>
          </Stack>
        )}
      </Box>
    </Stack>
  );
}
