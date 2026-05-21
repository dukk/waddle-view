import { useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { bffRecoveryExportDisplays } from '@/api/bffAuth';
import { BffError } from '@/api/bffClient';
import { useControllerAuth } from '@/context/ControllerAuthContext';
import { importDisplaysJson, setLocalDisplaysMigrationComplete } from '@/storage/displays';
import { saveSession } from '@/storage/sessions';

type DisplaysRecoverySectionProps = {
  onChanged: () => void;
};

export function DisplaysRecoverySection({ onChanged }: DisplaysRecoverySectionProps) {
  const { status } = useControllerAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ level: 'success' | 'error'; text: string } | null>(null);

  if (!status?.recoveryExportAvailable) {
    return null;
  }

  const recover = async () => {
    setMsg(null);
    setBusy(true);
    try {
      const payload = await bffRecoveryExportDisplays(username.trim(), password);
      importDisplaysJson(JSON.stringify(payload.displays));
      for (const [displayId, session] of Object.entries(payload.sessions)) {
        saveSession(displayId, session);
      }
      setLocalDisplaysMigrationComplete();
      setUsername('');
      setPassword('');
      onChanged();
      setMsg({
        level: 'success',
        text:
          'Display settings saved to this browser. User mode is off; they are stored locally until you turn user mode on again.',
      });
    } catch (e) {
      setMsg({ level: 'error', text: e instanceof BffError ? e.message : String(e) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Paper variant="outlined" sx={{ p: 2 }}>
      <Typography variant="subtitle1" fontWeight={600} gutterBottom>
        Recover display settings to this browser
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        User mode is off, but display pairings still exist on the server. Sign in once with a
        controller account to copy that account&apos;s displays and API keys into this browser.
      </Typography>
      {msg && (
        <Alert severity={msg.level} onClose={() => setMsg(null)} sx={{ mb: 2 }}>
          {msg.text}
        </Alert>
      )}
      <Stack spacing={2} direction={{ xs: 'column', sm: 'row' }} useFlexGap>
        <TextField
          label="Username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          disabled={busy}
          size="small"
          sx={{ minWidth: 160 }}
        />
        <TextField
          label="Password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          disabled={busy}
          size="small"
          sx={{ minWidth: 160 }}
        />
        <Box sx={{ display: 'flex', alignItems: 'center' }}>
          <Button
            variant="contained"
            disabled={busy || !username.trim() || !password}
            onClick={() => void recover()}
          >
            {busy ? 'Recovering…' : 'Recover to this browser'}
          </Button>
        </Box>
      </Stack>
    </Paper>
  );
}
