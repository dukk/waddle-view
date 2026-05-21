import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Alert,
  Box,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  FormControlLabel,
  Stack,
  Switch,
  Typography,
} from '@mui/material';
import { BffError } from '@/api/bffClient';
import { updateBffSettings } from '@/api/bffAuth';
import { isUserModeActive, useControllerAuth } from '@/context/ControllerAuthContext';

export function ControllerAccessSection() {
  const { status, refresh, isControllerAdmin } = useControllerAuth();
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [confirmDisableOpen, setConfirmDisableOpen] = useState(false);

  if (!status) return null;

  const userMode = isUserModeActive(status);

  const applyToggle = async (enabled: boolean) => {
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

  const onToggle = (enabled: boolean) => {
    if (!enabled && userMode) {
      setConfirmDisableOpen(true);
      return;
    }
    void applyToggle(enabled);
  };

  return (
    <Box>
      <Typography variant="subtitle1" gutterBottom>
        User mode
      </Typography>
      <Stack spacing={1.5}>
        <Stack direction="row" spacing={1} alignItems="center">
          <Typography variant="body2" color="text.secondary">
            Server authentication capability
          </Typography>
          <Chip
            size="small"
            label={status.authEnabled ? 'Enabled' : 'Disabled'}
            color={status.authEnabled ? 'success' : 'default'}
          />
        </Stack>
        {!status.authEnabled && (
          <Alert severity="info">
            Set <code>WADDLE_CONTROLLER_AUTH_ENABLED=1</code> on the controller BFF server, then use
            the switch below to turn on user mode (sign-in and per-account displays).
          </Alert>
        )}
        {error && <Alert severity="error">{error}</Alert>}
        <FormControlLabel
          control={
            <Switch
              checked={userMode}
              disabled={!status.authEnabled || !isControllerAdmin || busy}
              onChange={(_, checked) => onToggle(checked)}
            />
          }
          label="User mode"
        />
        <Typography variant="body2" color="text.secondary">
          When on, operators sign in to this controller and adopted displays are stored per account
          on the server. When off, use recovery on the Displays tab to copy server data into this
          browser once.
        </Typography>
        {userMode && isControllerAdmin && (
          <Typography variant="body2" color="text.secondary">
            Manage accounts in the table below.
          </Typography>
        )}
        {userMode && status.user && (
          <Typography variant="body2" color="text.secondary">
            Signed in as <strong>{status.user.username}</strong> ({status.user.role}).
          </Typography>
        )}
      </Stack>

      <Dialog open={confirmDisableOpen} onClose={() => setConfirmDisableOpen(false)}>
        <DialogTitle>Turn off user mode?</DialogTitle>
        <DialogContent>
          <DialogContentText>
            Per-account display settings remain on the server until someone signs in once and
            recovers them to this browser (Displays tab). New sign-ins will be disabled until user
            mode is turned on again.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmDisableOpen(false)}>Cancel</Button>
          <Button
            color="warning"
            variant="contained"
            disabled={busy}
            onClick={() => {
              setConfirmDisableOpen(false);
              void applyToggle(false);
            }}
          >
            Turn off user mode
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
