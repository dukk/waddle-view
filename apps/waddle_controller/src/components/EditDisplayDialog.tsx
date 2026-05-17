import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import type { SavedDisplay } from '@/storage/displays';
import { normalizeBaseUrl } from '@/storage/displays';
import { loadSession } from '@/storage/sessions';

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

  useEffect(() => {
    setLabel(display.label);
    setBaseUrl(display.baseUrl);
    setError(null);
  }, [display.id, display.label, display.baseUrl]);

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
      await onSave({ label: trimmedLabel, baseUrl: trimmedUrl });
      onClose();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
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
          Save
        </Button>
      </DialogActions>
    </Dialog>
  );
}
