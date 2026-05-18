import { useState } from 'react';
import { Alert, Button, Stack, TextField } from '@mui/material';
import { AuthPageShell } from '@/components/brand/AuthPageShell';
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
    <AuthPageShell
      title="Sign in to this controller"
      subtitle="Sign in to use the operator UI. Display adoption is separate and unchanged."
    >
      <Stack component="form" onSubmit={submit} spacing={2}>
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
    </AuthPageShell>
  );
}
