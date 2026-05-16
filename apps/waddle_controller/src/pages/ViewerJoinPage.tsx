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
import { registerViewerDisplay } from '@/api/auth';
import { useDisplay } from '@/context/DisplayContext';
import { normalizeBaseUrl, upsertDisplayByBaseUrl } from '@/storage/displays';
import { saveSession } from '@/storage/sessions';

export function ViewerJoinPage() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const { setActiveId, refresh } = useDisplay();

  const initialApi = useMemo(() => (params.get('api') ?? '').trim(), [params]);
  const secretFromQuery = useMemo(() => (params.get('secret') ?? '').trim(), [params]);
  const [apiUrl, setApiUrl] = useState(initialApi || 'http://127.0.0.1:8787');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);

  const canRegister =
    secretFromQuery.length > 0 &&
    password.length >= 8 &&
    username.trim().length > 0;

  const finishWithDisplaySession = (
    result: Awaited<ReturnType<typeof registerViewerDisplay>>,
  ) => {
    const d = upsertDisplayByBaseUrl({ baseUrl: result.baseUrl });
    saveSession(d.id, {
      token: result.token,
      expiresAtMs: result.expiresAtMs,
      user: result.user,
      permissions: result.permissions,
      warnings: result.warnings ?? [],
    });
    setActiveId(d.id);
    refresh();
    navigate('/');
  };

  const onRegister = async () => {
    setError(null);
    try {
      const api = normalizeBaseUrl(apiUrl);
      void new URL(api);
      const result = await registerViewerDisplay(api, {
        username: username.trim(),
        password,
        registrationSecret: secretFromQuery,
      });
      finishWithDisplaySession(result);
    } catch (e) {
      setError(String(e));
    }
  };

  const onSignInInstead = () => {
    setError(null);
    try {
      const api = normalizeBaseUrl(apiUrl);
      void new URL(api);
      const d = upsertDisplayByBaseUrl({ baseUrl: api });
      setActiveId(d.id);
      refresh();
      navigate('/');
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
        Connects waddle_controller to the kiosk REST API. When the display enables registration,
        new accounts are created with the <strong>viewer</strong> role (Programs and Account in this app; the display
        API grants <code>telemetry.read</code> for program data).
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
        {secretFromQuery ? (
          <>
            <TextField
              label="Username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              fullWidth
            />
            <TextField
              label="Password (min 8 characters)"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              fullWidth
              autoComplete="new-password"
            />
            <Button variant="contained" onClick={() => void onRegister()} disabled={!canRegister}>
              Create viewer account and sign in
            </Button>
          </>
        ) : (
          <Alert severity="info">
            This link has no registration secret. Configure{' '}
            <code>WADDLE_VIEWER_REGISTRATION_SECRET</code> on the display to allow self-service viewer
            signup (and add the controller origin to <code>WADDLE_HTTP_CORS_ORIGINS</code>). You can
            still sign in below.
          </Alert>
        )}
        <Button variant="outlined" onClick={onSignInInstead}>
          Sign in with an existing account
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
