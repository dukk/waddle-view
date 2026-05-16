import { useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  FormControl,
  InputLabel,
  List,
  ListItem,
  ListItemText,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { addDisplay } from '@/storage/displays';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch } from '@/api/client';
import { useColorMode } from '@/context/ColorModeContext';
import type { ColorModePreference } from '@/storage/colorModePreference';

function AppearancePreferencesSection() {
  const { preference, setPreference } = useColorMode();

  return (
    <Box>
      <Typography variant="subtitle1" gutterBottom>
        Appearance
      </Typography>
      <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1 }}>
        Defaults to your device light/dark setting. Stored only in this browser.
      </Typography>
      <FormControl sx={{ minWidth: 240 }}>
        <InputLabel id="controller-color-mode-label">Color mode</InputLabel>
        <Select
          labelId="controller-color-mode-label"
          label="Color mode"
          value={preference}
          onChange={(e) => setPreference(e.target.value as ColorModePreference)}
        >
          <MenuItem value="system">Match device</MenuItem>
          <MenuItem value="light">Light</MenuItem>
          <MenuItem value="dark">Dark</MenuItem>
        </Select>
      </FormControl>
    </Box>
  );
}

export function AccountPage() {
  const { displays, active, refresh, removeDisplay } = useDisplay();
  const { session, refreshSession } = useAuth();
  const [displayName, setDisplayName] = useState('');
  const [password, setPassword] = useState('');
  const [profileMsg, setProfileMsg] = useState<string | null>(null);
  const [passwordMsg, setPasswordMsg] = useState<string | null>(null);
  const [displayListMsg, setDisplayListMsg] = useState<{
    level: 'success' | 'error';
    text: string;
  } | null>(null);

  useEffect(() => {
    if (session?.user) {
      setDisplayName(session.user.display_name ?? '');
    }
  }, [session?.user]);

  const userId = session?.user.id;

  const saveProfile = async () => {
    if (!session || !active || !userId) return;
    setProfileMsg(null);
    try {
      await apiFetch(active, `/v1/users/${userId}`, {
        method: 'PATCH',
        body: JSON.stringify({ display_name: displayName }),
      });
      await refreshSession();
      setProfileMsg('Profile saved.');
    } catch (e) {
      setProfileMsg(String(e));
    }
  };

  const savePassword = async () => {
    if (!session || !active || !userId) return;
    setPasswordMsg(null);
    try {
      await apiFetch(active, `/v1/users/${userId}/password`, {
        method: 'POST',
        body: JSON.stringify({ password }),
      });
      setPassword('');
      setPasswordMsg('Password updated.');
    } catch (e) {
      setPasswordMsg(String(e));
    }
  };

  const body =
    session && active ? (
      <>
        <Box>
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>
            Username
          </Typography>
          <Typography variant="body1">{session.user.username}</Typography>
        </Box>

        <Box>
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>
            Role
          </Typography>
          <Typography variant="body1">{session.user.role}</Typography>
        </Box>

        <Box>
          <Typography variant="subtitle1" gutterBottom>
            Display name
          </Typography>
          <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1 }}>
            Shown in the header and session details. Leave blank to fall back to your username on the
            display.
          </Typography>
          {profileMsg && (
            <Alert severity={profileMsg.startsWith('Profile') ? 'success' : 'error'} sx={{ mb: 1 }}>
              {profileMsg}
            </Alert>
          )}
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'flex-start' }}>
            <TextField
              label="Display name"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              fullWidth
            />
            <Button variant="contained" onClick={() => void saveProfile()}>
              Save
            </Button>
          </Stack>
        </Box>

        <Box>
          <Typography variant="subtitle1" gutterBottom>
            Password
          </Typography>
          {passwordMsg && (
            <Alert severity={passwordMsg.startsWith('Password') ? 'success' : 'error'} sx={{ mb: 1 }}>
              {passwordMsg}
            </Alert>
          )}
          <Stack spacing={1} sx={{ maxWidth: 400 }}>
            <TextField
              type="password"
              label="New password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="new-password"
              fullWidth
            />
            <Button variant="outlined" onClick={() => void savePassword()} disabled={password.length < 8}>
              Update password
            </Button>
            <Typography variant="caption" color="text.secondary">
              At least 8 characters.
            </Typography>
          </Stack>
        </Box>
      </>
    ) : (
      <Typography variant="body1" color="text.secondary">
        Select a display and sign in to manage your account.
      </Typography>
    );

  return (
    <Stack spacing={3} sx={{ maxWidth: 720 }}>
      <Typography variant="h5" fontWeight={600}>
        Account
      </Typography>

      <AppearancePreferencesSection />

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
            setDisplayListMsg({ level: 'success', text: 'Display added.' });
          }}
        />
        {displayListMsg && (
          <Alert severity={displayListMsg.level} sx={{ mt: 2 }} onClose={() => setDisplayListMsg(null)}>
            {displayListMsg.text}
          </Alert>
        )}
      </Box>

      {body}
    </Stack>
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
