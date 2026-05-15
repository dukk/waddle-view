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
  const [label, setLabel] = useState('');
  const [error, setError] = useState<string | null>(null);

  const submit = () => {
    setError(null);
    try {
      const normalized = normalizeBaseUrl(baseUrl);
      void new URL(normalized);
      addNewDisplay({ baseUrl: normalized, label: label.trim() || undefined });
    } catch {
      setError('Enter a valid base URL (for example http://192.168.1.50:8787).');
    }
  };

  return (
    <Dialog open={open} fullWidth maxWidth="sm" disableEscapeKeyDown>
      <DialogTitle>Add a display</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}
          <Alert severity="info">
            You will sign in on the next step with a user account (or bootstrap user{' '}
            <strong>display</strong> using the instance id from the TV).
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
          Continue
        </Button>
      </DialogActions>
    </Dialog>
  );
}
