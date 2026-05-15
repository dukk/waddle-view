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
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';

export function LoginDialog() {
  const { active } = useDisplay();
  const { needsLogin, login } = useAuth();
  const [username, setUsername] = useState('display');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);

  const open = needsLogin && active != null;

  const submit = async () => {
    setError(null);
    try {
      await login(username.trim(), password);
      setPassword('');
    } catch (e) {
      setError(String(e));
    }
  };

  return (
    <Dialog open={open} fullWidth maxWidth="sm" disableEscapeKeyDown>
      <DialogTitle>Sign in to {active?.label ?? 'display'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}
          <Alert severity="info">
            First-time setup: use username <strong>display</strong> and the instance id from{' '}
            <code>waddle_instance.id</code> on the display device. Create a named user in Settings
            afterward.
          </Alert>
          <TextField
            label="Username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            fullWidth
            required
          />
          <TextField
            label="Password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            fullWidth
            required
            autoComplete="current-password"
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button variant="contained" onClick={() => void submit()} disabled={!password.trim()}>
          Sign in
        </Button>
      </DialogActions>
    </Dialog>
  );
}
