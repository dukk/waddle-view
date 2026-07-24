import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
} from '@mui/material';
import { apiFetch, ApiError } from '@/api/client';
import { ALERT_SEVERITY_LABELS } from '@/constants/alertEnumLabels';
import type { SavedDisplay } from '@/storage/displays';
import {
  alertExpireMinutesError,
  alertExpiresAtMs,
  parseAlertExpireMinutes,
} from '@/util/alertExpiry';
import { completeDialogSave } from '@/util/dialogSave';

type Props = {
  open: boolean;
  display: SavedDisplay;
  onClose: () => void;
  onSaved: () => void | Promise<void>;
};

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

const SEVERITY_OPTIONS = Object.entries(ALERT_SEVERITY_LABELS).map(([value, label]) => ({
  value,
  label,
}));

export function AlertEntryDialog({ open, display, onClose, onSaved }: Props) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [severity, setSeverity] = useState('info');
  const [priority, setPriority] = useState(0);
  const [expireMinutes, setExpireMinutes] = useState('60');
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setErr(null);
    setTitle('');
    setBody('');
    setSeverity('info');
    setPriority(0);
    setExpireMinutes('60');
  }, [open]);

  const save = useCallback(async () => {
    setErr(null);
    if (!title.trim()) {
      setErr('Title is required.');
      return;
    }
    if (!body.trim()) {
      setErr('Body is required.');
      return;
    }
    const expireErr = alertExpireMinutesError(expireMinutes);
    if (expireErr) {
      setErr(expireErr);
      return;
    }
    const minutes = parseAlertExpireMinutes(expireMinutes)!;
    setSaving(true);
    try {
      const payload: Record<string, unknown> = {
        title: title.trim(),
        body: body.trim(),
        severity,
        priority,
        source: 'manual_entry',
        expires_at: alertExpiresAtMs(minutes),
      };
      const res = await apiFetch(display, '/v1/alerts', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        const text = await res.text();
        setErr(text || `HTTP ${res.status}`);
        return;
      }
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      setErr(errMsg(e));
    } finally {
      setSaving(false);
    }
  }, [title, body, severity, priority, expireMinutes, display, onSaved, onClose]);

  return (
    <Dialog open={open} onClose={saving ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Add alert</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          <TextField
            label="Title"
            size="small"
            fullWidth
            required
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            disabled={saving}
          />
          <TextField
            label="Body"
            size="small"
            fullWidth
            required
            multiline
            minRows={3}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            disabled={saving}
          />
          <FormControl fullWidth size="small">
            <InputLabel id="alert-severity-label">Severity</InputLabel>
            <Select
              labelId="alert-severity-label"
              label="Severity"
              value={severity}
              onChange={(e) => setSeverity(e.target.value)}
              disabled={saving}
            >
              {SEVERITY_OPTIONS.map((o) => (
                <MenuItem key={o.value} value={o.value}>
                  {o.label}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <TextField
            label="Priority"
            type="number"
            size="small"
            fullWidth
            value={priority}
            onChange={(e) => setPriority(Number(e.target.value) || 0)}
            disabled={saving}
            helperText="Higher priority wins when multiple alerts are active."
          />
          <TextField
            label="Expire in (minutes)"
            type="number"
            size="small"
            fullWidth
            required
            value={expireMinutes}
            onChange={(e) => setExpireMinutes(e.target.value)}
            disabled={saving}
            helperText="Alert stops showing after this many minutes (1–10080)."
            slotProps={{
              htmlInput: { min: 1, max: 10080, step: 1 }
            }}
          />
          {err ? <Alert severity="error">{err}</Alert> : null}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={saving}>
          Cancel
        </Button>
        <Button variant="contained" onClick={() => void save()} disabled={saving}>
          {saving ? 'Creating…' : 'Create'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
