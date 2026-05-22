import { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, Box, Button, CircularProgress, Stack, Typography } from '@mui/material';
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
  autoConnect?: boolean;
};

export function RemoteViewPanel({
  display,
  popOutPath = '/remote/view',
  onDisconnect,
  initialTicket,
  vncPassword,
  passwordConfigured,
  autoConnect = true,
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
      <Stack direction="row" spacing={1} flexWrap="wrap">
        <Button
          size="small"
          variant="contained"
          disabled={status === 'connecting'}
          onClick={() => void connect()}
        >
          {status === 'connecting' ? 'Connecting…' : 'Connect'}
        </Button>
        <Button size="small" variant="outlined" disabled={status === 'idle'} onClick={disconnect}>
          Disconnect
        </Button>
        <Button
          size="small"
          variant="outlined"
          startIcon={<OpenInNewIcon />}
          onClick={() => void openPopOut()}
        >
          Open in new window
        </Button>
      </Stack>
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
        {status === 'connecting' && (
          <Stack
            alignItems="center"
            justifyContent="center"
            sx={{ position: 'absolute', inset: 0, bgcolor: 'rgba(0,0,0,0.5)' }}
          >
            <CircularProgress color="inherit" />
          </Stack>
        )}
      </Box>
    </Stack>
  );
}
