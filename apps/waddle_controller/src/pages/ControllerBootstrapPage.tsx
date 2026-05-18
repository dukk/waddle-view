import { useState } from 'react';
import { Alert, Button, Stack, TextField } from '@mui/material';
import { AuthPageShell } from '@/components/brand/AuthPageShell';
import { useControllerAuth } from '@/context/ControllerAuthContext';
import { BffError } from '@/api/bffClient';

export function ControllerBootstrapPage() {
  const { bootstrapAdmin } = useControllerAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (password !== confirm) {
      setError('Passwords do not match');
      return;
    }
    setBusy(true);
    try {
      await bootstrapAdmin(username, password);
    } catch (err) {
      setError(err instanceof BffError ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <AuthPageShell
      title="First administrator account"
      subtitle="User management was enabled but no accounts exist yet. Create the first administrator to continue."
      maxWidth={480}
    >
      <Stack component="form" onSubmit={submit} spacing={2}>
        {error && <Alert severity="error">{error}</Alert>}
        <TextField
          label="Admin username"
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
          autoComplete="new-password"
          helperText="At least 12 characters"
          required
        />
        <TextField
          label="Confirm password"
          type="password"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          autoComplete="new-password"
          required
        />
        <Button type="submit" variant="contained" disabled={busy}>
          Create admin
        </Button>
      </Stack>
    </AuthPageShell>
  );
}
