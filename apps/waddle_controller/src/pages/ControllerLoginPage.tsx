import { useState } from 'react';
import { Alert, Box, Button, Stack, TextField, Typography } from '@mui/material';
import { useControllerAuth } from '@/context/ControllerAuthContext';
import { BffError } from '@/api/bffClient';

export function ControllerLoginPage() {
  const { login } = useControllerAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await login(username, password);
    } catch (err) {
      setError(err instanceof BffError ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        p: 3,
      }}
    >
      <Stack component="form" onSubmit={submit} spacing={2} sx={{ width: '100%', maxWidth: 400 }}>
        <Typography variant="h5" fontWeight={600}>
          Sign in to this controller
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Sign in to use the operator UI. Display adoption is separate and unchanged.
        </Typography>
        {error && <Alert severity="error">{error}</Alert>}
        <TextField
          label="Username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          autoComplete="username"
          required
        />
        <TextField
          label="Password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="current-password"
          required
        />
        <Button type="submit" variant="contained" disabled={busy}>
          Sign in
        </Button>
      </Stack>
    </Box>
  );
}
