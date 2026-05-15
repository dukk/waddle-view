import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Divider,
  List,
  ListItem,
  ListItemText,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import {
  addDisplay,
  exportDisplaysJson,
  importDisplaysJson,
  importDisplaysJsonLegacy,
} from '@/storage/displays';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson } from '@/api/client';

type UserRow = {
  id: string;
  username: string;
  display_name: string;
  role: string;
  disabled: boolean;
};

export function SettingsPage() {
  const { displays, active, refresh, removeDisplay } = useDisplay();
  const { hasPermission, session, refreshSession } = useAuth();
  const [importText, setImportText] = useState('');
  const [msg, setMsg] = useState<{ level: 'success' | 'error'; text: string } | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const canManageUsers = hasPermission('users.manage');

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
      try {
        importDisplaysJson(importText);
      } catch {
        importDisplaysJsonLegacy(importText);
      }
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

      {session && (
        <Alert severity="info">
          Signed in as <strong>{session.user.username}</strong> ({session.user.role})
        </Alert>
      )}

      <Alert severity="info">
        <strong>Keyboard shortcuts</strong> (when focus is not in a text field): Left/Right arrows
        navigate the <strong>screen</strong> carousel; Up/Down navigate the <strong>ticker</strong>.
      </Alert>

      {canManageUsers && active && <UsersSection display={active} onChanged={() => void refreshSession()} />}

      {!canManageUsers && active && (
        <ProfilePasswordSection display={active} userId={session?.user.id ?? ''} />
      )}

      <Box>
        <Typography variant="subtitle1" gutterBottom>
          Displays ({displays.length})
        </Typography>
        <List dense>
          {displays.map((d) => (
            <ListItem
              key={d.id}
              secondaryAction={
                <Button size="small" color="error" onClick={() => removeDisplay(d.id)}>
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
              setImportText(await f.text());
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
    </Stack>
  );
}

function UsersSection({
  display,
  onChanged,
}: {
  display: { id: string; baseUrl: string; label: string };
  onChanged: () => void;
}) {
  const [users, setUsers] = useState<UserRow[]>([]);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState('operator');
  const [err, setErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    const body = await apiJson<{ items: UserRow[] }>(display, '/v1/users');
    setUsers(body.items);
  }, [display]);

  useEffect(() => {
    void load().catch((e) => setErr(String(e)));
  }, [load]);

  const create = async () => {
    setErr(null);
    try {
      await apiFetch(display, '/v1/users', {
        method: 'POST',
        body: JSON.stringify({ username, password, role }),
      });
      setUsername('');
      setPassword('');
      await load();
      onChanged();
    } catch (e) {
      setErr(String(e));
    }
  };

  return (
    <Box>
      <Typography variant="subtitle1" gutterBottom>
        Users
      </Typography>
      {err && <Alert severity="error">{err}</Alert>}
      <List dense>
        {users.map((u) => (
          <ListItem key={u.id}>
            <ListItemText
              primary={`${u.username} (${u.role})${u.disabled ? ' [disabled]' : ''}`}
              secondary={u.display_name}
            />
          </ListItem>
        ))}
      </List>
      <Stack spacing={1} sx={{ mt: 2 }}>
        <Typography variant="subtitle2">Create user</Typography>
        <TextField label="Username" value={username} onChange={(e) => setUsername(e.target.value)} />
        <TextField
          label="Password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <TextField select label="Role" value={role} onChange={(e) => setRole(e.target.value)}>
          <MenuItem value="admin">admin</MenuItem>
          <MenuItem value="operator">operator</MenuItem>
          <MenuItem value="viewer">viewer</MenuItem>
        </TextField>
        <Button variant="contained" onClick={() => void create()}>
          Create
        </Button>
      </Stack>
    </Box>
  );
}

function ProfilePasswordSection({
  display,
  userId,
}: {
  display: { id: string; baseUrl: string; label: string };
  userId: string;
}) {
  const [password, setPassword] = useState('');
  const [msg, setMsg] = useState<string | null>(null);

  const submit = async () => {
    if (!userId) return;
    try {
      await apiFetch(display, `/v1/users/${userId}/password`, {
        method: 'POST',
        body: JSON.stringify({ password }),
      });
      setPassword('');
      setMsg('Password updated.');
    } catch (e) {
      setMsg(String(e));
    }
  };

  return (
    <Box>
      <Typography variant="subtitle1" gutterBottom>
        Change your password
      </Typography>
      {msg && <Alert severity="info">{msg}</Alert>}
      <Stack spacing={1}>
        <TextField
          type="password"
          label="New password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <Button variant="outlined" onClick={() => void submit()}>
          Update password
        </Button>
      </Stack>
    </Box>
  );
}

function AddDisplayInline({ onAdded }: { onAdded: () => void }) {
  const [baseUrl, setBaseUrl] = useState('http://127.0.0.1:8787');
  const [label, setLabel] = useState('');
  const [err, setErr] = useState<string | null>(null);

  const submit = () => {
    setErr(null);
    try {
      addDisplay({ baseUrl, label: label.trim() || undefined });
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
      <TextField label="Label" value={label} onChange={(e) => setLabel(e.target.value)} />
      <Button variant="outlined" onClick={submit}>
        Add
      </Button>
    </Stack>
  );
}
