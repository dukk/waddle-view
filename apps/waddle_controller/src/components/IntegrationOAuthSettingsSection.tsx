import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Button,
  Chip,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { ApiError } from '@/api/client';
import { listOAuthProviders, putOAuthProviderClientId, type OAuthProviderStatus } from '@/api/oauthProviders';
import type { SavedDisplay } from '@/storage/displays';

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

export function IntegrationOAuthSettingsSection({
  display,
  canWrite,
}: {
  display: SavedDisplay;
  canWrite: boolean;
}) {
  const [providers, setProviders] = useState<OAuthProviderStatus[]>([]);
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const items = await listOAuthProviders(display);
      setProviders(items);
    } catch (e) {
      setError(errMsg(e));
    }
  }, [display]);

  useEffect(() => {
    void load();
  }, [load]);

  const save = async (provider: OAuthProviderStatus) => {
    const value = (drafts[provider.id] ?? '').trim();
    if (!value) {
      setError('Enter a client ID before saving.');
      return;
    }
    setBusyId(provider.id);
    setError(null);
    try {
      await putOAuthProviderClientId(display, provider.id, value);
      setDrafts((prev) => ({ ...prev, [provider.id]: '' }));
      await load();
    } catch (e) {
      setError(errMsg(e));
    } finally {
      setBusyId(null);
    }
  };

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        OAuth app client IDs for Google and Microsoft sign-in. Values are stored encrypted on the
        display. After saving a client ID, you can add matching accounts on the Integrations page.
      </Typography>
      {error ? <Alert severity="error">{error}</Alert> : null}
      {providers.map((provider) => (
        <Stack key={provider.id} spacing={1}>
          <Stack direction="row" alignItems="center" spacing={1}>
            <Typography variant="subtitle2">{provider.label}</Typography>
            {provider.client_id_configured ? (
              <Chip size="small" color="success" label="Configured" />
            ) : (
              <Chip size="small" color="warning" label="Required for sign-in" />
            )}
          </Stack>
          <TextField
            label={`${provider.label} OAuth client ID`}
            value={drafts[provider.id] ?? ''}
            onChange={(e) =>
              setDrafts((prev) => ({ ...prev, [provider.id]: e.target.value }))
            }
            fullWidth
            size="small"
            disabled={!canWrite}
            placeholder={
              provider.client_id_configured
                ? 'Enter a new value to replace the stored client ID'
                : 'Paste client ID from your cloud app registration'
            }
          />
          {canWrite ? (
            <Button
              variant="outlined"
              size="small"
              sx={{ alignSelf: 'flex-start' }}
              disabled={busyId === provider.id || (drafts[provider.id] ?? '').trim().length === 0}
              onClick={() => void save(provider)}
            >
              {busyId === provider.id ? 'Saving…' : 'Save client ID'}
            </Button>
          ) : null}
        </Stack>
      ))}
    </Stack>
  );
}
