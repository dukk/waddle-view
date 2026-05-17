import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Alert,
  Box,
  Chip,
  FormControlLabel,
  Stack,
  Switch,
  Typography,
} from '@mui/material';
import { BffError } from '@/api/bffClient';
import { updateBffSettings } from '@/api/bffAuth';
import { useControllerAuth } from '@/context/ControllerAuthContext';

export function ControllerAccessSection() {
  const { status, refresh, isControllerAdmin } = useControllerAuth();
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (!status) return null;

  const onToggle = async (enabled: boolean) => {
    setError(null);
    setBusy(true);
    try {
      const res = await updateBffSettings(enabled);
      await refresh();
      if (res.needsBootstrap) {
        navigate('/controller-bootstrap', { replace: true });
      }
    } catch (e) {
      setError(e instanceof BffError ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Box>
      <Typography variant="subtitle1" gutterBottom>
        Controller access
      </Typography>
      <Stack spacing={1.5}>
        <Stack direction="row" spacing={1} alignItems="center">
          <Typography variant="body2" color="text.secondary">
            Server authentication
          </Typography>
          <Chip
            size="small"
            label={status.authEnabled ? 'Enabled' : 'Disabled'}
            color={status.authEnabled ? 'success' : 'default'}
          />
        </Stack>
        {!status.authEnabled && (
          <Alert severity="info">
            Set <code>WADDLE_CONTROLLER_AUTH_ENABLED=1</code> on the controller BFF server to require
            sign-in. User management requires authentication.
          </Alert>
        )}
        {error && <Alert severity="error">{error}</Alert>}
        <FormControlLabel
          control={
            <Switch
              checked={status.userManagementEnabled}
              disabled={!status.authEnabled || !isControllerAdmin || busy}
              onChange={(_, checked) => void onToggle(checked)}
            />
          }
          label="Enable user management"
        />
        {status.userManagementEnabled && isControllerAdmin && (
          <Typography variant="body2" color="text.secondary">
            Open the <strong>Users</strong> tab to manage controller accounts.
          </Typography>
        )}
        {status.authEnabled && status.user && (
          <Typography variant="body2" color="text.secondary">
            Signed in to controller as <strong>{status.user.username}</strong> ({status.user.role}
            ).
          </Typography>
        )}
      </Stack>
    </Box>
  );
}
