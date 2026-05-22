import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Stack,
  Typography,
} from '@mui/material';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import { createLivePreviewSession } from '@/api/displayLivePreview';
import type { SavedDisplay } from '@/storage/displays';
import { openLivePreviewPopOut } from '@/util/openLivePreviewPopOut';
import {
  buildLivePreviewWebSocketUrl,
  consumeLivePreviewTestPayload,
} from '@/util/livePreviewWsUrl';

const LIVE_PREVIEW_FRAME_HEADER_BYTES = 5;
const LIVE_PREVIEW_LEGACY_HEADER_BYTES = 4;

function parseLivePreviewFrame(buf: ArrayBuffer): {
  mime: string;
  payload: ArrayBuffer;
} | null {
  if (buf.byteLength < LIVE_PREVIEW_LEGACY_HEADER_BYTES) return null;
  const view = new DataView(buf);
  const len = view.getUint32(0, false);
  if (len <= 0) return null;

  const bytes = new Uint8Array(buf);
  const legacy =
    bytes.length >= LIVE_PREVIEW_LEGACY_HEADER_BYTES + len &&
    bytes[LIVE_PREVIEW_LEGACY_HEADER_BYTES] === 0xff &&
    bytes[LIVE_PREVIEW_LEGACY_HEADER_BYTES + 1] === 0xd8 &&
    bytes[4] !== 0 &&
    bytes[4] !== 1;

  if (legacy) {
    return {
      mime: 'image/jpeg',
      payload: buf.slice(
        LIVE_PREVIEW_LEGACY_HEADER_BYTES,
        LIVE_PREVIEW_LEGACY_HEADER_BYTES + len,
      ),
    };
  }

  if (buf.byteLength < LIVE_PREVIEW_FRAME_HEADER_BYTES + len) return null;
  const format = view.getUint8(4);
  const mime = format === 1 ? 'image/png' : 'image/jpeg';
  return {
    mime,
    payload: buf.slice(
      LIVE_PREVIEW_FRAME_HEADER_BYTES,
      LIVE_PREVIEW_FRAME_HEADER_BYTES + len,
    ),
  };
}

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
  const [status, setStatus] = useState<LivePreviewConnectionStatus>('idle');
  const [error, setError] = useState<string | null>(null);
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

  const disconnect = useCallback(() => {
    wsRef.current?.close();
    wsRef.current = null;
    revokeBlob();
    setConnectionStatus('idle');
    onDisconnect?.();
  }, [onDisconnect, revokeBlob, setConnectionStatus]);

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
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- connect once on mount
  }, []);

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
          <Stack alignItems="center" spacing={2} sx={{ p: 2, textAlign: 'center' }}>
            {status === 'connecting' ? (
              <>
                <CircularProgress color="inherit" />
                <Typography variant="body2" color="grey.400">
                  Connecting live preview…
                </Typography>
              </>
            ) : (
              <Typography variant="body2" color="grey.400">
                View-only stream from the display app window.
              </Typography>
            )}
          </Stack>
        )}
      </Box>
      <Stack direction="row" spacing={1} flexWrap="wrap" sx={{ flexShrink: 0 }}>
        {status === 'connected' ? (
          <Button variant="outlined" onClick={disconnect}>
            Disconnect
          </Button>
        ) : (
          <Button variant="contained" onClick={() => void connect()} disabled={status === 'connecting'}>
            Connect
          </Button>
        )}
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
