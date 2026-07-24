import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Stack,
  Typography,
} from '@mui/material';
import DownloadIcon from '@mui/icons-material/Download';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import { createLivePreviewSession } from '@/api/displayLivePreview';
import type { SavedDisplay } from '@/storage/displays';
import {
  downloadLivePreviewFrameToBrowser,
  parseLivePreviewFrame,
  type LivePreviewFrame,
} from '@/util/livePreviewFrame';
import { openLivePreviewPopOut } from '@/util/openLivePreviewPopOut';
import {
  buildLivePreviewWebSocketUrl,
  consumeLivePreviewTestPayload,
} from '@/util/livePreviewWsUrl';

export type LivePreviewConnectionStatus = 'idle' | 'connecting' | 'connected' | 'error';

type Props = {
  display: SavedDisplay;
  popOutPath?: string;
  onDisconnect?: () => void;
  onStatusChange?: (status: LivePreviewConnectionStatus) => void;
  initialTicket?: string;
  autoConnect?: boolean;
  showPopOut?: boolean;
  /** Fills parent height without fixed min-heights (pop-out window). */
  layout?: 'default' | 'embedded';
};

export function LivePreviewPanel({
  display,
  popOutPath = '/remote/view',
  onDisconnect,
  onStatusChange,
  initialTicket,
  autoConnect = false,
  showPopOut = true,
  layout = 'default',
}: Props) {
  const embedded = layout === 'embedded';
  const imgRef = useRef<HTMLImageElement>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const blobUrlRef = useRef<string | null>(null);
  const latestFrameRef = useRef<LivePreviewFrame | null>(null);
  const [status, setStatus] = useState<LivePreviewConnectionStatus>('idle');
  const [error, setError] = useState<string | null>(null);
  const [hasFrame, setHasFrame] = useState(false);
  const [tinyFrameWarning, setTinyFrameWarning] = useState(false);

  const setConnectionStatus = useCallback(
    (next: LivePreviewConnectionStatus) => {
      setStatus(next);
      onStatusChange?.(next);
    },
    [onStatusChange],
  );

  const revokeBlob = useCallback(() => {
    if (blobUrlRef.current) {
      URL.revokeObjectURL(blobUrlRef.current);
      blobUrlRef.current = null;
    }
  }, []);

  const clearLatestFrame = useCallback(() => {
    latestFrameRef.current = null;
    setHasFrame(false);
  }, []);

  const disconnect = useCallback(() => {
    wsRef.current?.close();
    wsRef.current = null;
    revokeBlob();
    clearLatestFrame();
    setConnectionStatus('idle');
    onDisconnect?.();
  }, [clearLatestFrame, onDisconnect, revokeBlob, setConnectionStatus]);

  const connect = useCallback(
    async (ticketOverride?: string) => {
      setError(null);
      setConnectionStatus('connecting');
      try {
        const testPayload = consumeLivePreviewTestPayload(display.id);
        let ticket = ticketOverride ?? initialTicket ?? testPayload?.ticket;
        if (!ticket) {
          const session = await createLivePreviewSession(display);
          ticket = session.ticket;
        }
        const wsUrl = buildLivePreviewWebSocketUrl(display, ticket, {
          baseUrlOverride: testPayload?.baseUrl,
        });

        wsRef.current?.close();
        const ws = new WebSocket(wsUrl);
        ws.binaryType = 'arraybuffer';
        wsRef.current = ws;

        ws.onopen = () => setConnectionStatus('connected');
        ws.onclose = () => {
          setConnectionStatus('idle');
          onDisconnect?.();
        };
        ws.onerror = () => {
          setConnectionStatus('error');
          setError('Live preview connection failed.');
        };
        ws.onmessage = (ev) => {
          if (!(ev.data instanceof ArrayBuffer)) return;
          const parsed = parseLivePreviewFrame(ev.data);
          if (!parsed) return;
          latestFrameRef.current = parsed;
          setHasFrame(true);
          revokeBlob();
          const blob = new Blob([parsed.payload], { type: parsed.mime });
          blobUrlRef.current = URL.createObjectURL(blob);
          if (imgRef.current) {
            imgRef.current.src = blobUrlRef.current;
            imgRef.current.onload = () => {
              const w = imgRef.current?.naturalWidth ?? 0;
              const h = imgRef.current?.naturalHeight ?? 0;
              setTinyFrameWarning(w <= 2 || h <= 2);
            };
          }
        };
      } catch (e) {
        setConnectionStatus('error');
        setError(String(e));
      }
    },
    [display, initialTicket, onDisconnect, revokeBlob, setConnectionStatus],
  );

  useEffect(() => {
    if (!autoConnect) return;
    void connect();
    return () => {
      wsRef.current?.close();
      wsRef.current = null;
      revokeBlob();
      latestFrameRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- connect once on mount
  }, []);

  const saveFrame = useCallback(() => {
    const frame = latestFrameRef.current;
    if (!frame) return;
    downloadLivePreviewFrameToBrowser(frame, display.id);
  }, [display.id]);

  const openPopOut = useCallback(async () => {
    try {
      const session = await createLivePreviewSession(display);
      openLivePreviewPopOut(
        { displayId: display.id, ticket: session.ticket },
        popOutPath,
      );
    } catch (e) {
      setError(String(e));
      setConnectionStatus('error');
    }
  }, [display, popOutPath, setConnectionStatus]);

  const showPlaceholder = status !== 'connected';

  return (
    <Stack
      spacing={1}
      sx={{
        height: embedded ? '100%' : undefined,
        minHeight: embedded ? 0 : 320,
        flex: embedded ? 1 : undefined,
        minWidth: 0,
      }}
    >
      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}
      {tinyFrameWarning && (
        <Alert severity="warning" onClose={() => setTinyFrameWarning(false)}>
          Preview frame is 1×1 or empty — the display is using the test capture backend. On
          Windows, restart the display app so widget capture is active; on Pi, check GStreamer or
          ffmpeg and window XID.
        </Alert>
      )}
      <Box
        sx={{
          flex: 1,
          minHeight: embedded ? 0 : 280,
          flexShrink: embedded ? 1 : undefined,
          bgcolor: 'grey.900',
          borderRadius: 1,
          overflow: 'hidden',
          position: 'relative',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Box
          component="img"
          ref={imgRef}
          alt="Live display preview"
          sx={{
            maxWidth: '100%',
            maxHeight: '100%',
            objectFit: 'contain',
            display: showPlaceholder ? 'none' : 'block',
          }}
        />
        {showPlaceholder && (
          <Stack
            spacing={2}
            sx={{
              alignItems: "center",
              p: 2,
              textAlign: 'center'
            }}>
            {status === 'connecting' ? (
              <>
                <CircularProgress color="inherit" />
                <Typography variant="body2" sx={{
                  color: "grey.400"
                }}>
                  Connecting live preview…
                </Typography>
              </>
            ) : (
              <Typography variant="body2" sx={{
                color: "grey.400"
              }}>
                View-only stream from the display app window.
              </Typography>
            )}
          </Stack>
        )}
      </Box>
      <Stack
        direction="row"
        spacing={1}
        sx={{
          flexWrap: "wrap",
          flexShrink: 0
        }}>
        {status === 'connected' ? (
          <Button variant="outlined" onClick={disconnect}>
            Disconnect
          </Button>
        ) : (
          <Button variant="contained" onClick={() => void connect()} disabled={status === 'connecting'}>
            Connect
          </Button>
        )}
        <Button
          variant="outlined"
          startIcon={<DownloadIcon />}
          disabled={status !== 'connected' || !hasFrame}
          onClick={saveFrame}
        >
          Save frame
        </Button>
        {showPopOut && (
          <Button
            variant="outlined"
            startIcon={<OpenInNewIcon />}
            onClick={() => void openPopOut()}
          >
            Open in new window
          </Button>
        )}
      </Stack>
    </Stack>
  );
}
