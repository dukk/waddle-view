import { useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Link,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
  confirmAdoption,
  requestAdoption,
  sessionFromAdoption,
} from '@/api/adoption';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { normalizeBaseUrl, upsertDisplayByBaseUrl } from '@/storage/displays';
import { saveSession } from '@/storage/sessions';
import { AdoptionChallengeCodeField } from '@/components/AdoptionChallengeCodeField';
import {
  isAdoptionChallengeCodeComplete,
  normalizeAdoptionChallengeCode,
} from '@/util/adoptionChallengeCode';
import { adoptionError, adoptionLog } from '@/util/adoptionLog';

function defaultViewerIdentifier(): string {
  const host =
    typeof window !== 'undefined' ? window.location.hostname : 'viewer';
  return `viewer-${host}`;
}

export function ViewerJoinPage() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const { setActiveId, refresh } = useDisplay();
  const { saveAdoptionSession } = useAuth();

  const initialApi = useMemo(() => (params.get('api') ?? '').trim(), [params]);
  const [apiUrl, setApiUrl] = useState(initialApi || 'http://127.0.0.1:8787');
  const [identifier, setIdentifier] = useState(defaultViewerIdentifier);
  const [challengeCode, setChallengeCode] = useState('');
  const [pendingConfirm, setPendingConfirm] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const onRequest = async () => {
    setError(null);
    setBusy(true);
    const api = normalizeBaseUrl(apiUrl);
    adoptionLog('ui.join.request.start', 'viewer join requested adoption', {
      baseUrl: api,
      identifier: identifier.trim(),
      role: 'viewer',
    });
    try {
      void new URL(api);
      await requestAdoption(api, {
        identifier: identifier.trim(),
        role: 'viewer',
      });
      setChallengeCode('');
      setPendingConfirm(true);
      adoptionLog('ui.join.request.success', 'viewer join awaiting kiosk code');
    } catch (e) {
      adoptionError('ui.join.request.failed', 'viewer join request failed', {
        error: String(e),
      });
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const onConfirm = async () => {
    setError(null);
    setBusy(true);
    const api = normalizeBaseUrl(apiUrl);
    adoptionLog('ui.join.confirm.start', 'viewer join confirming adoption', {
      baseUrl: api,
      identifier: identifier.trim(),
      challenge_code: challengeCode.trim(),
    });
    try {
      const result = await confirmAdoption(api, {
        identifier: identifier.trim(),
        challenge_code: normalizeAdoptionChallengeCode(challengeCode),
      });
      const d = upsertDisplayByBaseUrl({ baseUrl: api });
      const session = sessionFromAdoption(api, result);
      saveSession(d.id, session);
      saveAdoptionSession(session);
      setActiveId(d.id);
      refresh();
      adoptionLog('ui.join.confirm.success', 'viewer join complete', {
        displayId: d.id,
      });
      navigate('/');
    } catch (e) {
      adoptionError('ui.join.confirm.failed', 'viewer join confirm failed', {
        error: String(e),
      });
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const onManageDisplays = () => {
    setError(null);
    try {
      const api = normalizeBaseUrl(apiUrl);
      void new URL(api);
      const d = upsertDisplayByBaseUrl({ baseUrl: api });
      setActiveId(d.id);
      refresh();
      navigate('/displays');
    } catch {
      setError('Enter a valid display API base URL.');
    }
  };

  return (
    <Box sx={{ p: 3, maxWidth: 520, mx: 'auto' }}>
      <Typography variant="h5" gutterBottom>
        Join this display
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Adopt this browser as a <strong>viewer</strong> client. Confirm the challenge code shown on
        the kiosk alert (same flow as Manage displays).
      </Typography>
      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}
      <Stack spacing={2}>
        <TextField
          label="Display API base URL"
          value={apiUrl}
          onChange={(e) => setApiUrl(e.target.value)}
          fullWidth
          helperText="Usually pre-filled from the QR link (?api=…)."
        />
        <TextField
          label="Client identifier"
          value={identifier}
          onChange={(e) => setIdentifier(e.target.value)}
          fullWidth
        />
        {!pendingConfirm ? (
          <Button variant="contained" onClick={() => void onRequest()} disabled={busy}>
            Request viewer adoption
          </Button>
        ) : (
          <>
            <AdoptionChallengeCodeField
              label="Challenge code"
              value={challengeCode}
              onChange={setChallengeCode}
              fullWidth
              helperText="Must match the code on the kiosk alert (XXXX-XXXX)."
            />
            <Button
              variant="contained"
              onClick={() => void onConfirm()}
              disabled={busy || !isAdoptionChallengeCodeComplete(challengeCode)}
            >
              Confirm and open Programs
            </Button>
          </>
        )}
        <Button variant="outlined" onClick={onManageDisplays}>
          Manage displays (other roles)
        </Button>
        <Typography variant="caption" color="text.secondary">
          Operator UI:{' '}
          <Link href="https://github.com/dukk/waddle-view/tree/main/apps/waddle_controller">
            waddle_controller
          </Link>
        </Typography>
      </Stack>
    </Box>
  );
}
