import { useState } from 'react';
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
} from '@mui/material';
import { useDisplay } from '@/context/DisplayContext';
import { normalizeBaseUrl } from '@/storage/displays';

export function FirstRunDialog() {
  const { displays, addNewDisplay } = useDisplay();
  const open = displays.length === 0;
  const [baseUrl, setBaseUrl] = useState('http://127.0.0.1:8787');
  const [apiKey, setApiKey] = useState('');
  const [label, setLabel] = useState('');
  const [error, setError] = useState<string | null>(null);

  const submit = () => {
    setError(null);
    const key = apiKey.trim();
    if (!key) {
      setError('API key is required (same value as in your display key file).');
      return;
    }
    let normalized: string;
    try {
      normalized = normalizeBaseUrl(baseUrl);
      void new URL(normalized);
    } catch {
      setError('Enter a valid base URL (for example http://192.168.1.50:8787).');
      return;
    }
    addNewDisplay({ baseUrl: normalized, apiKey: key, label: label.trim() || undefined });
    setApiKey('');
  };

  return (
    <Dialog open={open} fullWidth maxWidth="sm" disableEscapeKeyDown>
      <DialogTitle>Add a display</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}
          <Alert severity="info">
            The controller stores the API key only in this browser&apos;s{' '}
            <strong>localStorage</strong>. Use a dedicated operator machine or profile; do not
            paste production keys on shared workstations.
          </Alert>
          <TextField
            label="Display base URL"
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            fullWidth
            required
            helperText="REST root of the running waddle_display instance (no trailing slash)."
          />
          <TextField
            label="API key"
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
            fullWidth
            required
            type="password"
            autoComplete="off"
          />
          <TextField
            label="Label (optional)"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            fullWidth
            helperText="Shown in the sidebar when you manage multiple displays."
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button variant="contained" onClick={submit}>
          Save and continue
        </Button>
      </DialogActions>
    </Dialog>
  );
}
