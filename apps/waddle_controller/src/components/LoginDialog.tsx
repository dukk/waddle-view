import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { AdoptionChallengeCodeField } from '@/components/AdoptionChallengeCodeField';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { isAdoptionChallengeCodeComplete } from '@/util/adoptionChallengeCode';

function defaultIdentifier(): string {
  const host =
    typeof window !== 'undefined' ? window.location.hostname : 'controller';
  return `controller-${host}`;
}

export function LoginDialog() {
  const navigate = useNavigate();
  const { active } = useDisplay();
  const { needsLogin, completeAdoption, loginDialogOpen, closeLoginDialog, session } =
    useAuth();

  const [identifier, setIdentifier] = useState('');
  const [challengeCode, setChallengeCode] = useState('');
  const [error, setError] = useState<string | null>(null);

  const open = loginDialogOpen;

  useEffect(() => {
    if (!open || !active) return;
    setIdentifier(session?.identifier ?? defaultIdentifier());
    setChallengeCode('');
    setError(null);
  }, [open, active, session]);

  const submit = async () => {
    setError(null);
    try {
      await completeAdoption(identifier.trim(), challengeCode.trim());
    } catch (e) {
      setError(String(e));
    }
  };

  const dismissToDisplays = () => {
    closeLoginDialog();
    navigate('/displays');
  };

  const canSubmit =
    identifier.trim().length > 0 && isAdoptionChallengeCodeComplete(challengeCode);

  return (
    <Dialog open={open} fullWidth maxWidth="sm" onClose={dismissToDisplays}>
      <DialogTitle>Adopt {active?.label ?? 'display'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}
          <Alert severity="info">
            <Typography variant="body2">
              Enter the <strong>challenge code</strong> shown on the kiosk security alert
              (format XXXX-XXXX).
            </Typography>
          </Alert>
          <TextField
            label="Client identifier"
            value={identifier}
            onChange={(e) => setIdentifier(e.target.value)}
            fullWidth
            required
          />
          <AdoptionChallengeCodeField
            label="Challenge code"
            value={challengeCode}
            onChange={setChallengeCode}
            fullWidth
            required
            helperText="Must match the code on the kiosk alert."
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={dismissToDisplays} color="inherit">
          {needsLogin ? 'Manage displays' : 'Cancel'}
        </Button>
        <Button variant="contained" onClick={() => void submit()} disabled={!canSubmit}>
          Confirm adoption
        </Button>
      </DialogActions>
    </Dialog>
  );
}
