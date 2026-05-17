import { useState } from 'react';
import {
  Alert,
  Button,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { requestAdoption } from '@/api/adoption';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { normalizeBaseUrl } from '@/storage/displays';
import { completeDisplayAdoption } from '@/util/completeDisplayAdoption';
import { AdoptionChallengeCodeField } from '@/components/AdoptionChallengeCodeField';
import { isAdoptionChallengeCodeComplete } from '@/util/adoptionChallengeCode';
import { adoptionError, adoptionLog } from '@/util/adoptionLog';

const ROLES = [
  { value: 'admin', label: 'Admin' },
  { value: 'operator', label: 'Operator' },
  { value: 'power_viewer', label: 'Power viewer' },
  { value: 'viewer', label: 'Viewer' },
] as const;

function defaultIdentifier(): string {
  const host =
    typeof window !== 'undefined' ? window.location.hostname : 'controller';
  return `wc-${host}`;
}

type Props = {
  /** Primary button label before the challenge step. */
  requestLabel?: string;
  onAdopted?: () => void;
};

export function AdoptDisplayForm({
  requestLabel = 'Request adoption',
  onAdopted,
}: Props) {
  const { refresh, setActiveId } = useDisplay();
  const { saveAdoptionSession } = useAuth();
  const [baseUrl, setBaseUrl] = useState('http://127.0.0.1:8787');
  const [label, setLabel] = useState('');
  const [identifier, setIdentifier] = useState(defaultIdentifier);
  const [role, setRole] = useState<string>('admin');
  const [challengeCode, setChallengeCode] = useState('');
  const [pendingConfirm, setPendingConfirm] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submitRequest = async () => {
    setError(null);
    setInfo(null);
    setBusy(true);
    const normalized = normalizeBaseUrl(baseUrl);
    adoptionLog('ui.request.start', 'operator requested adoption', {
      baseUrl: normalized,
      label: label.trim() || null,
      identifier: identifier.trim(),
      role,
    });
    try {
      void new URL(normalized);
      const result = await requestAdoption(normalized, {
        identifier: identifier.trim(),
        role,
      });
      setChallengeCode('');
      setPendingConfirm(true);
      setInfo(
        'A challenge code was shown on the kiosk alert. Enter that code below to prove you can see the display.',
      );
      adoptionLog('ui.request.success', 'awaiting operator-entered challenge', {
        expires_at_ms: result.expires_at_ms,
      });
    } catch (e) {
      adoptionError('ui.request.failed', 'request step failed', {
        error: String(e),
      });
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const submitConfirm = async () => {
    setError(null);
    setInfo(null);
    setBusy(true);
    adoptionLog('ui.confirm.start', 'operator completing adoption', {
      baseUrl: normalizeBaseUrl(baseUrl),
      identifier: identifier.trim(),
      challenge_code: challengeCode.trim(),
    });
    try {
      const { display, session } = await completeDisplayAdoption({
        baseUrl,
        label: label.trim() || undefined,
        identifier,
        challengeCode,
      });
      setActiveId(display.id);
      saveAdoptionSession(session);
      refresh();
      setPendingConfirm(false);
      setChallengeCode('');
      setLabel('');
      adoptionLog('ui.confirm.success', 'adoption flow finished', {
        displayId: display.id,
        activeRole: session.role,
      });
      onAdopted?.();
    } catch (e) {
      adoptionError('ui.confirm.failed', 'confirm step failed', {
        error: String(e),
      });
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Stack spacing={2}>
      {error && <Alert severity="error">{error}</Alert>}
      {info && <Alert severity="info">{info}</Alert>}
      <TextField
        label="Display base URL"
        value={baseUrl}
        onChange={(e) => setBaseUrl(e.target.value)}
        fullWidth
        required
        disabled={pendingConfirm}
        helperText="REST root of waddle_display (no trailing slash)."
      />
      <TextField
        label="Label (optional)"
        value={label}
        onChange={(e) => setLabel(e.target.value)}
        fullWidth
        disabled={pendingConfirm}
        helperText="Shown in the display menu when you manage multiple kiosks."
      />
      <TextField
        label="Client identifier"
        value={identifier}
        onChange={(e) => setIdentifier(e.target.value)}
        fullWidth
        required
        disabled={pendingConfirm}
        helperText="Shown on the kiosk adoption alert."
      />
      <FormControl fullWidth disabled={pendingConfirm}>
        <InputLabel id="adopt-role-label">Role</InputLabel>
        <Select
          labelId="adopt-role-label"
          label="Role"
          value={role}
          onChange={(e) => setRole(e.target.value)}
        >
          {ROLES.map((r) => (
            <MenuItem key={r.value} value={r.value}>
              {r.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      {!pendingConfirm ? (
        <Button variant="contained" onClick={() => void submitRequest()} disabled={busy}>
          {requestLabel}
        </Button>
      ) : (
        <>
          <AdoptionChallengeCodeField
            label="Challenge code"
            value={challengeCode}
            onChange={setChallengeCode}
            fullWidth
            required
            helperText="Must match the code on the kiosk alert (XXXX-XXXX)."
          />
          <Stack direction="row" spacing={1}>
            <Button
              variant="contained"
              onClick={() => void submitConfirm()}
              disabled={busy || !isAdoptionChallengeCodeComplete(challengeCode)}
            >
              Complete adoption
            </Button>
            <Button
              color="inherit"
              disabled={busy}
              onClick={() => {
                setPendingConfirm(false);
                setChallengeCode('');
                setInfo(null);
              }}
            >
              Cancel
            </Button>
          </Stack>
        </>
      )}
      {!pendingConfirm && (
        <Typography variant="body2" color="text.secondary">
          Requesting adoption shows a challenge on the kiosk. The display is saved only after
          you complete adoption successfully.
        </Typography>
      )}
    </Stack>
  );
}
