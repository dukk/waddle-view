import { useEffect, useMemo, useState } from 'react';
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
  Box,
  Button,
  Link,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
  confirmAdoption,
  requestAdoption,
  sessionFromAdoption,
} from '@/api/adoption';
import { useAuth } from '@/context/AuthContext';
import { useControllerAuth } from '@/context/ControllerAuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { syncUserDisplayToServer } from '@/storage/userDisplaysSync';
import { resolveClientIdentifier } from '@/util/clientIdentifier';
import { normalizeBaseUrl, upsertDisplayByBaseUrl } from '@/storage/displays';
import { saveSession } from '@/storage/sessions';
import { AdoptionChallengeCodeField } from '@/components/AdoptionChallengeCodeField';
import {
  isAdoptionChallengeCodeComplete,
  normalizeAdoptionChallengeCode,
} from '@/util/adoptionChallengeCode';
import { adoptionErrorMessage } from '@/util/adoptionFetchError';
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
  const { status } = useControllerAuth();
  const clientId = resolveClientIdentifier(status, defaultViewerIdentifier());

  const initialApi = useMemo(() => (params.get('api') ?? '').trim(), [params]);
  const [apiUrl, setApiUrl] = useState(initialApi || 'https://127.0.0.1:8787');
  const [identifier, setIdentifier] = useState(clientId.value);
  const [challengeCode, setChallengeCode] = useState('');
  const [pendingConfirm, setPendingConfirm] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (clientId.locked) {
      setIdentifier(clientId.value);
    }
  }, [clientId.locked, clientId.value]);

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
      setError(adoptionErrorMessage(e));
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
      await syncUserDisplayToServer(d, session).catch(() => undefined);
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
      setError(adoptionErrorMessage(e));
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
      navigate('/controller-settings');
    } catch {
      setError('Enter a valid display API base URL.');
    }
  };

  return (
    <Box sx={{ p: 3, maxWidth: 520, mx: 'auto' }}>
      <Typography variant="h5" fontWeight={600} gutterBottom>
        Viewer pairing
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Pair this browser as a <strong>viewer</strong> client with read-focused permissions. Enter
        the challenge code from the kiosk alert—the same adoption flow as Controller settings, but
        the display issues a viewer role instead of operator or admin.
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
        <Accordion>
          <AccordionSummary expandIcon={<ExpandMoreIcon />}>
            <Typography variant="subtitle2">Advanced</Typography>
          </AccordionSummary>
          <AccordionDetails>
            <TextField
              label="Client identifier"
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              fullWidth
              disabled={clientId.locked}
              helperText={
                clientId.locked
                  ? 'Set by WADDLE_CONTROLLER_CLIENT_IDENTIFIER on the server.'
                  : undefined
              }
            />
          </AccordionDetails>
        </Accordion>
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
              onEnter={() => {
                if (!busy && isAdoptionChallengeCodeComplete(challengeCode)) {
                  void onConfirm();
                }
              }}
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
