import { useRef, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Divider,
  List,
  ListItem,
  ListItemText,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import {
  addDisplay,
  exportDisplaysJson,
  importDisplaysJson,
} from '@/storage/displays';
import { useDisplay } from '@/context/DisplayContext';

export function SettingsPage() {
  const { displays, active, refresh, removeDisplay } = useDisplay();
  const [importText, setImportText] = useState('');
  const [msg, setMsg] = useState<{ level: 'success' | 'error'; text: string } | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const exportBlob = () => {
    const blob = new Blob([exportDisplaysJson()], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'waddle_controller_displays.json';
    a.click();
    URL.revokeObjectURL(url);
  };

  const doImport = () => {
    setMsg(null);
    try {
      importDisplaysJson(importText);
      setImportText('');
      refresh();
      setMsg({ level: 'success', text: 'Imported display list.' });
    } catch (e) {
      setMsg({ level: 'error', text: String(e) });
    }
  };

  return (
    <Stack spacing={3} sx={{ maxWidth: 720 }}>
      <Typography variant="h5" fontWeight={600}>
        Settings
      </Typography>

      <Alert severity="info">
        <strong>Keyboard shortcuts</strong> (when focus is not in a text field): Left/Right
        arrows navigate the <strong>screen</strong> carousel; Up/Down navigate the{' '}
        <strong>ticker</strong>. They call <code>POST /v1/display/navigation</code> on the selected
        display.
      </Alert>

      <Box>
        <Typography variant="subtitle1" gutterBottom>
          Displays ({displays.length})
        </Typography>
        <Typography variant="body2" color="text.secondary" paragraph>
          Saved in this browser&apos;s <code>localStorage</code> under{' '}
          <code>waddle_controller_displays_v1</code>. Clearing site data removes them.
        </Typography>
        <List dense>
          {displays.map((d) => (
            <ListItem
              key={d.id}
              secondaryAction={
                <Button
                  size="small"
                  color="error"
                  onClick={() => {
                    removeDisplay(d.id);
                  }}
                >
                  Remove
                </Button>
              }
            >
              <ListItemText
                primary={`${d.label}${active?.id === d.id ? ' (active)' : ''}`}
                secondary={d.baseUrl}
              />
            </ListItem>
          ))}
        </List>
        <AddDisplayInline
          onAdded={() => {
            refresh();
            setMsg({ level: 'success', text: 'Display added.' });
          }}
        />
      </Box>

      <Divider />

      <Box>
        <Typography variant="subtitle1" gutterBottom>
          Backup / restore
        </Typography>
        <Stack direction="row" spacing={1} sx={{ mb: 2 }}>
          <Button variant="outlined" onClick={exportBlob}>
            Export JSON
          </Button>
          <Button variant="outlined" onClick={() => fileRef.current?.click()}>
            Import from file
          </Button>
          <input
            ref={fileRef}
            type="file"
            accept="application/json,.json"
            hidden
            onChange={async (ev) => {
              const f = ev.target.files?.[0];
              ev.target.value = '';
              if (!f) return;
              const text = await f.text();
              setImportText(text);
            }}
          />
        </Stack>
        <TextField
          label="Paste JSON to import"
          value={importText}
          onChange={(e) => setImportText(e.target.value)}
          fullWidth
          multiline
          minRows={4}
        />
        <Button sx={{ mt: 1 }} variant="contained" onClick={doImport} disabled={!importText.trim()}>
          Apply import
        </Button>
      </Box>

      {msg && (
        <Alert severity={msg.level} onClose={() => setMsg(null)}>
          {msg.text}
        </Alert>
      )}

      <Alert severity="warning">
        For local development, run <code>npm run dev</code> in <code>apps/waddle_controller</code>{' '}
        and point the display base URL at your device. If the SPA origin differs from the API
        origin, set <code>WADDLE_HTTP_CORS_ORIGINS</code> on the display (comma-separated) so the
        browser allows fetch calls.
      </Alert>
    </Stack>
  );
}

function AddDisplayInline({ onAdded }: { onAdded: () => void }) {
  const [baseUrl, setBaseUrl] = useState('http://127.0.0.1:8787');
  const [apiKey, setApiKey] = useState('');
  const [label, setLabel] = useState('');
  const [err, setErr] = useState<string | null>(null);

  const submit = () => {
    setErr(null);
    const key = apiKey.trim();
    if (!key) {
      setErr('API key required.');
      return;
    }
    try {
      addDisplay({ baseUrl, apiKey: key, label: label.trim() || undefined });
      setApiKey('');
      onAdded();
    } catch (e) {
      setErr(String(e));
    }
  };

  return (
    <Stack spacing={1} sx={{ mt: 2 }}>
      <Typography variant="subtitle2">Add another display</Typography>
      {err && <Alert severity="error">{err}</Alert>}
      <TextField label="Base URL" value={baseUrl} onChange={(e) => setBaseUrl(e.target.value)} />
      <TextField
        label="API key"
        type="password"
        value={apiKey}
        onChange={(e) => setApiKey(e.target.value)}
      />
      <TextField label="Label" value={label} onChange={(e) => setLabel(e.target.value)} />
      <Button variant="outlined" onClick={submit}>
        Add
      </Button>
    </Stack>
  );
}
