import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Alert, Button, Stack, TextField } from '@mui/material';
import { AuthPageShell } from '@/components/brand/AuthPageShell';
import { BffError } from '@/api/bffClient';
import { bffChangePassword } from '@/api/bffAuth';
import { useControllerAuth } from '@/context/ControllerAuthContext';

export function ControllerChangePasswordPage() {
  const { refresh } = useControllerAuth();
  const navigate = useNavigate();
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (newPassword !== confirm) {
      setError('Passwords do not match');
      return;
    }
    setBusy(true);
    try {
      await bffChangePassword(currentPassword, newPassword);
      await refresh();
      navigate('/', { replace: true });
    } catch (err) {
      setError(err instanceof BffError ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <AuthPageShell
      title="Change your password"
      subtitle="Your administrator requires a new password before you can continue."
      maxWidth={480}
    >
      <Stack component="form" onSubmit={submit} spacing={2}>
        {error && <Alert severity="error">{error}</Alert>}
        <TextField
          label="Current password"
          type="password"
          value={currentPassword}
          onChange={(e) => setCurrentPassword(e.target.value)}
          autoComplete="current-password"
          required
          disabled={busy}
        />
        <TextField
          label="New password"
          type="password"
          value={newPassword}
          onChange={(e) => setNewPassword(e.target.value)}
          autoComplete="new-password"
          helperText="At least 12 characters"
          required
          disabled={busy}
        />
        <TextField
          label="Confirm new password"
          type="password"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          autoComplete="new-password"
          required
          disabled={busy}
        />
        <Button type="submit" variant="contained" disabled={busy}>
          {busy ? 'Updating…' : 'Update password'}
        </Button>
      </Stack>
    </AuthPageShell>
  );
}
