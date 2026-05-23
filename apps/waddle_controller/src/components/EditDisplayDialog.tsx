import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Button,
  Collapse,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Switch,
  TextField,
  Typography,
} from '@mui/material';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import {
  DEFAULT_LIVE_PREVIEW_FPS,
  DEFAULT_LIVE_PREVIEW_QUALITY,
  DEFAULT_LIVE_PREVIEW_WIDTH,
  isLivePreviewWidthPreset,
  LIVE_PREVIEW_WIDTH_OPTIONS,
  normalizeLivePreviewWidth,
} from '@/constants/livePreviewSettings';
import type { SavedDisplay } from '@/storage/displays';
import { normalizeBaseUrl } from '@/storage/displays';
import { loadSession } from '@/storage/sessions';
import { completeDialogSave } from '@/util/dialogSave';
import { fetchDisplaySettings } from '@/api/displaySettings';
import {
  createLivePreviewSessionForBaseUrl,
  putLivePreviewSettings,
} from '@/api/displayLivePreview';
import { openLivePreviewPopOut } from '@/util/openLivePreviewPopOut';
import { storeLivePreviewTestPayload } from '@/util/livePreviewWsUrl';

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
  const [previewLoading, setPreviewLoading] = useState(false);
  const [livePreviewOpen, setLivePreviewOpen] = useState(false);
  const [livePreviewEnabled, setLivePreviewEnabled] = useState(false);
  const [livePreviewFps, setLivePreviewFps] = useState(DEFAULT_LIVE_PREVIEW_FPS);
  const [livePreviewWidth, setLivePreviewWidth] = useState(DEFAULT_LIVE_PREVIEW_WIDTH);
  const [livePreviewQuality, setLivePreviewQuality] = useState(DEFAULT_LIVE_PREVIEW_QUALITY);
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

  const loadPreviewSettings = useCallback(async () => {
    if (!loadSession(display.id)) return;
    setPreviewLoading(true);
    try {
      const settings = await fetchDisplaySettings(display);
      setLivePreviewEnabled(settings.display_live_preview_enabled === true);
      setLivePreviewFps(settings.display_live_preview_fps ?? DEFAULT_LIVE_PREVIEW_FPS);
      setLivePreviewWidth(
        normalizeLivePreviewWidth(settings.display_live_preview_width ?? DEFAULT_LIVE_PREVIEW_WIDTH),
      );
      setLivePreviewQuality(
        settings.display_live_preview_quality ?? DEFAULT_LIVE_PREVIEW_QUALITY,
      );
    } catch (e) {
      setError(String(e));
    } finally {
      setPreviewLoading(false);
    }
  }, [display]);

  useEffect(() => {
    setLabel(display.label);
    setBaseUrl(display.baseUrl);
    setError(null);
    void loadPreviewSettings();
  }, [display.id, display.label, display.baseUrl, loadPreviewSettings]);

  const persistLivePreviewSettings = async (targetBaseUrl: string) => {
    const fps = livePreviewFps;
    const width = livePreviewWidth;
    const quality = livePreviewQuality;
    if (!Number.isFinite(fps) || fps < 1 || fps > 30) {
      throw new Error('Live preview FPS must be between 1 and 30.');
    }
    if (!isLivePreviewWidthPreset(width)) {
      throw new Error('Live preview capture width must be a preset value.');
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
      openLivePreviewPopOut({ displayId: display.id, ticket: sessionRes.ticket });
    } catch (e) {
      setError(String(e));
    } finally {
      setTestBusy(false);
    }
  };

  return (
    <Dialog open onClose={busy ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Edit display</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}
          {baseUrlChanged && (
            <Alert severity="info">
              Base URL changed — save to update this display&apos;s connection. Live preview settings
              are written to the URL in the form when you save or test.
            </Alert>
          )}
          <TextField
            label="Label"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            fullWidth
            disabled={busy}
            autoFocus
          />
          <TextField
            label="Base URL"
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            fullWidth
            disabled={busy}
            helperText="HTTPS origin of the display REST API (e.g. https://192.168.1.10:8787)."
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
            {livePreviewOpen ? 'Hide' : 'Show'} live preview
          </Button>
          <Collapse in={livePreviewOpen}>
            <Stack spacing={2} sx={{ pl: 0.5, minHeight: previewLoading ? 200 : undefined }}>
              {!session ? (
                <Typography variant="body2" color="text.secondary">
                  Adopt this display to configure live preview on the device.
                </Typography>
              ) : previewLoading ? (
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
                    View-only JPEG stream from the display window (GStreamer on Linux, widget
                    capture on Windows/macOS dev).
                  </Typography>
                  <CuratorSliderField
                    label="FPS"
                    value={livePreviewFps}
                    onChange={setLivePreviewFps}
                    min={1}
                    max={30}
                    step={1}
                    disabled={!livePreviewEnabled || busy}
                  />
                  <FormControl fullWidth disabled={!livePreviewEnabled || busy}>
                    <InputLabel id="live-preview-width-label">Capture width</InputLabel>
                    <Select
                      labelId="live-preview-width-label"
                      label="Capture width"
                      value={livePreviewWidth}
                      onChange={(e) => setLivePreviewWidth(Number(e.target.value))}
                    >
                      {LIVE_PREVIEW_WIDTH_OPTIONS.map((opt) => (
                        <MenuItem key={opt.value} value={opt.value}>
                          {opt.label}
                        </MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                  <CuratorSliderField
                    label="JPEG quality"
                    value={livePreviewQuality}
                    onChange={setLivePreviewQuality}
                    min={30}
                    max={95}
                    step={1}
                    disabled={!livePreviewEnabled || busy}
                  />
                  <Typography variant="caption" color="text.secondary">
                    Lower JPEG quality reduces Pi CPU and bandwidth (30–95).
                  </Typography>
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
