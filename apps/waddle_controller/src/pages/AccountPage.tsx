import { useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch } from '@/api/client';

export function AccountPage() {
  const { active } = useDisplay();
  const { session, refreshSession } = useAuth();
  const [displayName, setDisplayName] = useState('');
  const [password, setPassword] = useState('');
  const [profileMsg, setProfileMsg] = useState<string | null>(null);
  const [passwordMsg, setPasswordMsg] = useState<string | null>(null);

  useEffect(() => {
    if (session?.user) {
      setDisplayName(session.user.display_name ?? '');
    }
  }, [session?.user]);

  if (!session || !active) {
    return (
      <Typography variant="body1" color="text.secondary">
        Select a display and sign in to manage your account.
      </Typography>
    );
  }

  const userId = session.user.id;

  const saveProfile = async () => {
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

  return (
    <Stack spacing={3} sx={{ maxWidth: 520 }}>
      <Typography variant="h5" fontWeight={600}>
        Account
      </Typography>

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
    </Stack>
  );
}
