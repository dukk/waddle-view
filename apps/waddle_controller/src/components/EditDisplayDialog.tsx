import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Button,
  Collapse,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  Stack,
  Switch,
  TextField,
  Typography,
} from '@mui/material';
import type { SavedDisplay } from '@/storage/displays';
import { normalizeBaseUrl } from '@/storage/displays';
import { loadSession } from '@/storage/sessions';
import { completeDialogSave } from '@/util/dialogSave';
import { fetchDisplaySettings } from '@/api/displaySettings';
import {
  createLivePreviewSessionForBaseUrl,
  putLivePreviewSettings,
} from '@/api/displayLivePreview';
import {
  createRemoteViewSessionForBaseUrl,
  deleteRemoteViewPassword,
  putRemoteViewPassword,
  putRemoteViewSettings,
} from '@/api/displayRemoteView';
import { storeLivePreviewTestPayload } from '@/util/livePreviewWsUrl';
import { storeRemoteViewTestPayload } from '@/util/remoteViewWsUrl';

export type EditDisplayInput = {
  label: string;
  baseUrl: string;
};

type Props = {
  display: SavedDisplay;
  onClose: () => void;
  onSave: (input: EditDisplayInput) => Promise<void>;
};

export function EditDisplayDialog({ display, onClose, onSave }: Props) {
  const session = loadSession(display.id);
  const [label, setLabel] = useState(display.label);
  const [baseUrl, setBaseUrl] = useState(display.baseUrl);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [remoteLoading, setRemoteLoading] = useState(false);
  const [remoteOpen, setRemoteOpen] = useState(false);
  const [livePreviewOpen, setLivePreviewOpen] = useState(false);
  const [livePreviewEnabled, setLivePreviewEnabled] = useState(false);
  const [livePreviewFps, setLivePreviewFps] = useState('10');
  const [livePreviewWidth, setLivePreviewWidth] = useState('1280');
  const [livePreviewQuality, setLivePreviewQuality] = useState('75');
  const [remoteEnabled, setRemoteEnabled] = useState(false);
  const [remoteHost, setRemoteHost] = useState('127.0.0.1');
  const [remotePort, setRemotePort] = useState('6080');
  const [remotePath, setRemotePath] = useState('/');
  const [remotePassword, setRemotePassword] = useState('');
  const [remotePasswordConfigured, setRemotePasswordConfigured] = useState(false);
  const [clearRemotePassword, setClearRemotePassword] = useState(false);
  const [testBusy, setTestBusy] = useState(false);

  const originalBaseUrl = useMemo(
    () => normalizeBaseUrl(display.baseUrl),
    [display.baseUrl],
  );

  const baseUrlChanged = useMemo(() => {
    const trimmed = baseUrl.trim();
    if (!trimmed) return false;
    try {
      return normalizeBaseUrl(trimmed) !== originalBaseUrl;
    } catch {
      return true;
    }
  }, [baseUrl, originalBaseUrl]);

  const loadRemoteSettings = useCallback(async () => {
    if (!loadSession(display.id)) return;
    setRemoteLoading(true);
    try {
      const settings = await fetchDisplaySettings(display);
      setRemoteEnabled(settings.display_remote_view_enabled === true);
      setRemoteHost(settings.display_remote_view_host?.trim() || '127.0.0.1');
      setRemotePort(String(settings.display_remote_view_port ?? 6080));
      setRemotePath(settings.display_remote_view_path?.trim() || '/');
      setRemotePasswordConfigured(settings.display_remote_view_password_configured === true);
      setRemotePassword('');
      setClearRemotePassword(false);
      setLivePreviewEnabled(settings.display_live_preview_enabled === true);
      setLivePreviewFps(String(settings.display_live_preview_fps ?? 10));
      setLivePreviewWidth(String(settings.display_live_preview_width ?? 1280));
      setLivePreviewQuality(String(settings.display_live_preview_quality ?? 75));
    } catch (e) {
      setError(String(e));
    } finally {
      setRemoteLoading(false);
    }
  }, [display]);

  useEffect(() => {
    setLabel(display.label);
    setBaseUrl(display.baseUrl);
    setError(null);
    void loadRemoteSettings();
  }, [display.id, display.label, display.baseUrl, loadRemoteSettings]);

  const persistLivePreviewSettings = async (targetBaseUrl: string) => {
    const fps = Number.parseInt(livePreviewFps.trim(), 10);
    const width = Number.parseInt(livePreviewWidth.trim(), 10);
    const quality = Number.parseInt(livePreviewQuality.trim(), 10);
    if (!Number.isFinite(fps) || fps < 1 || fps > 30) {
      throw new Error('Live preview FPS must be between 1 and 30.');
    }
    if (!Number.isFinite(width) || width < 320 || width > 3840) {
      throw new Error('Live preview width must be between 320 and 3840.');
    }
    if (!Number.isFinite(quality) || quality < 30 || quality > 95) {
      throw new Error('Live preview JPEG quality must be between 30 and 95.');
    }
    const draftDisplay: SavedDisplay = {
      ...display,
      baseUrl: normalizeBaseUrl(targetBaseUrl),
    };
    await putLivePreviewSettings(draftDisplay, {
      display_live_preview_enabled: livePreviewEnabled,
      display_live_preview_fps: fps,
      display_live_preview_width: width,
      display_live_preview_quality: quality,
    });
  };

  const persistRemoteSettings = async (targetBaseUrl: string) => {
    const port = Number.parseInt(remotePort.trim(), 10);
    if (!Number.isFinite(port) || port < 1 || port > 65535) {
      throw new Error('Remote view port must be between 1 and 65535.');
    }
    const draftDisplay: SavedDisplay = {
      ...display,
      baseUrl: normalizeBaseUrl(targetBaseUrl),
    };
    await putRemoteViewSettings(draftDisplay, {
      display_remote_view_enabled: remoteEnabled,
      display_remote_view_host: remoteHost.trim() || '127.0.0.1',
      display_remote_view_port: port,
      display_remote_view_path: remotePath.trim() || '/',
    });
    if (clearRemotePassword) {
      await deleteRemoteViewPassword(draftDisplay);
    } else if (remotePassword.trim()) {
      await putRemoteViewPassword(draftDisplay, remotePassword.trim());
    }
  };

  const submit = async () => {
    const trimmedLabel = label.trim();
    const trimmedUrl = baseUrl.trim();
    if (!trimmedLabel) {
      setError('Label is required.');
      return;
    }
    if (!trimmedUrl) {
      setError('Base URL is required.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await completeDialogSave(async () => {
        await onSave({ label: trimmedLabel, baseUrl: trimmedUrl });
        if (session) {
          await persistLivePreviewSettings(trimmedUrl);
          await persistRemoteSettings(trimmedUrl);
        }
      }, onClose);
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const testLivePreviewConnection = async () => {
    const trimmedUrl = baseUrl.trim();
    if (!trimmedUrl) {
      setError('Base URL is required to test live preview.');
      return;
    }
    if (!session) {
      setError('Adopt this display before testing live preview.');
      return;
    }
    if (!livePreviewEnabled) {
      setError('Enable live preview before testing.');
      return;
    }
    setTestBusy(true);
    setError(null);
    try {
      const normalized = normalizeBaseUrl(trimmedUrl);
      await persistLivePreviewSettings(normalized);
      const sessionRes = await createLivePreviewSessionForBaseUrl(
        normalized,
        display.id,
        `Bearer ${session.apiKey}`,
      );
      storeLivePreviewTestPayload({
        displayId: display.id,
        ticket: sessionRes.ticket,
        baseUrl: normalized,
      });
      const params = new URLSearchParams({
        displayId: display.id,
        ticket: sessionRes.ticket,
        mode: 'live',
      });
      window.open(`/remote/view?${params.toString()}`, '_blank', 'noopener,noreferrer');
    } catch (e) {
      setError(String(e));
    } finally {
      setTestBusy(false);
    }
  };

  const testRemoteConnection = async () => {
    const trimmedUrl = baseUrl.trim();
    if (!trimmedUrl) {
      setError('Base URL is required to test remote view.');
      return;
    }
    if (!session) {
      setError('Adopt this display before testing remote view.');
      return;
    }
    if (!remoteEnabled) {
      setError('Enable remote view before testing.');
      return;
    }
    setTestBusy(true);
    setError(null);
    try {
      const normalized = normalizeBaseUrl(trimmedUrl);
      const port = Number.parseInt(remotePort.trim(), 10);
      if (!Number.isFinite(port) || port < 1 || port > 65535) {
        throw new Error('Remote view port must be between 1 and 65535.');
      }
      await putRemoteViewSettings(
        { ...display, baseUrl: normalized },
        {
          display_remote_view_enabled: true,
          display_remote_view_host: remoteHost.trim() || '127.0.0.1',
          display_remote_view_port: port,
          display_remote_view_path: remotePath.trim() || '/',
        },
      );
      if (remotePassword.trim()) {
        await putRemoteViewPassword({ ...display, baseUrl: normalized }, remotePassword.trim());
      }
      const sessionRes = await createRemoteViewSessionForBaseUrl(
        normalized,
        display.id,
        `Bearer ${session.apiKey}`,
      );
      storeRemoteViewTestPayload({
        displayId: display.id,
        ticket: sessionRes.ticket,
        vncPassword: remotePassword.trim() || undefined,
        baseUrl: normalized,
      });
      const params = new URLSearchParams({
        displayId: display.id,
        ticket: sessionRes.ticket,
      });
      window.open(`/remote/view?${params.toString()}`, '_blank', 'noopener,noreferrer');
    } catch (e) {
      setError(String(e));
    } finally {
      setTestBusy(false);
    }
  };

  return (
    <Dialog open fullWidth maxWidth="sm" onClose={onClose}>
      <DialogTitle>Edit display</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}
          {baseUrlChanged && (
            <Alert severity="warning">
              Changing the base URL points this saved entry at a different display. Your existing API
              key only works if it was issued for that display — verify the URL, or re-adopt if
              requests fail.
            </Alert>
          )}
          <TextField
            label="Label"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            fullWidth
            required
            autoFocus
            helperText="Shown in the display menu and toolbar."
          />
          <TextField
            label="Base URL"
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            fullWidth
            required
            helperText="REST root of waddle_display (no trailing slash)."
            slotProps={{
              input: {
                sx: { fontFamily: 'monospace', fontSize: '0.85rem' },
              },
            }}
          />
          <Typography variant="body2" color="text.secondary">
            {session ? (
              <>
                Adopted as <strong>{session.identifier}</strong> ({session.role}).
              </>
            ) : (
              'Not adopted — use Adopt display or enter an API key to connect.'
            )}
          </Typography>

          <Button
            size="small"
            onClick={() => setLivePreviewOpen((o) => !o)}
            sx={{ alignSelf: 'flex-start' }}
          >
            {livePreviewOpen ? 'Hide' : 'Show'} live preview (in-app)
          </Button>
          <Collapse in={livePreviewOpen}>
            <Stack spacing={2} sx={{ pl: 0.5, minHeight: remoteLoading ? 200 : undefined }}>
              {!session ? (
                <Typography variant="body2" color="text.secondary">
                  Adopt this display to configure live preview on the device.
                </Typography>
              ) : remoteLoading ? (
                <Typography variant="body2" color="text.secondary">
                  Loading live preview settings…
                </Typography>
              ) : (
                <>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={livePreviewEnabled}
                        onChange={(e) => setLivePreviewEnabled(e.target.checked)}
                        disabled={busy}
                      />
                    }
                    label="Enable live preview"
                  />
                  <Typography variant="caption" color="text.secondary">
                    View-only JPEG stream from the display window (GStreamer on Linux). No VNC or
                    websockify required.
                  </Typography>
                  <TextField
                    label="FPS"
                    value={livePreviewFps}
                    onChange={(e) => setLivePreviewFps(e.target.value)}
                    fullWidth
                    disabled={!livePreviewEnabled || busy}
                    type="number"
                  />
                  <TextField
                    label="Capture width (px)"
                    value={livePreviewWidth}
                    onChange={(e) => setLivePreviewWidth(e.target.value)}
                    fullWidth
                    disabled={!livePreviewEnabled || busy}
                    type="number"
                  />
                  <TextField
                    label="JPEG quality"
                    value={livePreviewQuality}
                    onChange={(e) => setLivePreviewQuality(e.target.value)}
                    fullWidth
                    disabled={!livePreviewEnabled || busy}
                    type="number"
                    helperText="30–95. Lower values reduce Pi CPU and bandwidth."
                  />
                  <Button
                    variant="outlined"
                    disabled={!livePreviewEnabled || busy || testBusy}
                    onClick={() => void testLivePreviewConnection()}
                  >
                    {testBusy ? 'Testing…' : 'Test live preview'}
                  </Button>
                </>
              )}
            </Stack>
          </Collapse>

          <Button
            size="small"
            onClick={() => setRemoteOpen((o) => !o)}
            sx={{ alignSelf: 'flex-start' }}
          >
            {remoteOpen ? 'Hide' : 'Show'} remote view (VNC, legacy)
          </Button>
          <Collapse in={remoteOpen}>
            <Stack
              spacing={2}
              sx={{
                pl: 0.5,
                minHeight: remoteLoading ? 280 : undefined,
              }}
            >
              {!session ? (
                <Typography variant="body2" color="text.secondary">
                  Adopt this display to configure remote view on the display device.
                </Typography>
              ) : remoteLoading ? (
                <Typography variant="body2" color="text.secondary">
                  Loading remote view settings…
                </Typography>
              ) : (
                <>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={remoteEnabled}
                        onChange={(e) => setRemoteEnabled(e.target.checked)}
                        disabled={busy}
                      />
                    }
                    label="Enable remote view"
                  />
                  <TextField
                    label="Websockify host"
                    value={remoteHost}
                    onChange={(e) => setRemoteHost(e.target.value)}
                    fullWidth
                    disabled={!remoteEnabled || busy}
                    helperText="Host where websockify listens (often 127.0.0.1 on the display device)."
                  />
                  <TextField
                    label="Port"
                    value={remotePort}
                    onChange={(e) => setRemotePort(e.target.value)}
                    fullWidth
                    disabled={!remoteEnabled || busy}
                    type="number"
                  />
                  <TextField
                    label="WebSocket path"
                    value={remotePath}
                    onChange={(e) => setRemotePath(e.target.value)}
                    fullWidth
                    disabled={!remoteEnabled || busy}
                    helperText="Path on the websockify listener (default /)."
                  />
                  <TextField
                    label="VNC password"
                    type="password"
                    value={remotePassword}
                    onChange={(e) => setRemotePassword(e.target.value)}
                    fullWidth
                    disabled={!remoteEnabled || busy}
                    helperText={
                      remotePasswordConfigured
                        ? 'Leave blank to keep the current password on the display.'
                        : 'Optional; stored encrypted on the display.'
                    }
                    autoComplete="new-password"
                  />
                  {remotePasswordConfigured && (
                    <FormControlLabel
                      control={
                        <Switch
                          checked={clearRemotePassword}
                          onChange={(e) => setClearRemotePassword(e.target.checked)}
                          disabled={!remoteEnabled || busy}
                        />
                      }
                      label="Clear stored VNC password"
                    />
                  )}
                  <Button
                    variant="outlined"
                    disabled={!remoteEnabled || busy || testBusy}
                    onClick={() => void testRemoteConnection()}
                  >
                    {testBusy ? 'Testing…' : 'Test remote connection'}
                  </Button>
                </>
              )}
            </Stack>
          </Collapse>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={busy}>
          Cancel
        </Button>
        <Button
          variant="contained"
          onClick={() => void submit()}
          disabled={busy || !label.trim() || !baseUrl.trim()}
        >
          {busy ? 'Saving…' : 'Save'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
