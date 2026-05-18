import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { ApiError } from '@/api/client';
import {
  listOAuthProviders,
  putOAuthProviderClientId,
  type OAuthProviderStatus,
} from '@/api/oauthProviders';
import type { SavedDisplay } from '@/storage/displays';

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

function addClientIdDisabledReason(
  providers: OAuthProviderStatus[],
  unconfiguredCount: number,
  loading: boolean,
): string | null {
  if (loading) {
    return 'Loading account providers…';
  }
  if (providers.length === 0) {
    return 'No OAuth account providers are available on this display.';
  }
  if (unconfiguredCount === 0) {
    return 'Every supported account provider already has a client ID. Use Replace on a row to change one.';
  }
  return null;
}

export function IntegrationOAuthSettingsSection({
  display,
  canWrite,
}: {
  display: SavedDisplay;
  canWrite: boolean;
}) {
  const [providers, setProviders] = useState<OAuthProviderStatus[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [replaceProvider, setReplaceProvider] = useState<OAuthProviderStatus | null>(null);

  const load = useCallback(async () => {
    setError(null);
    setLoading(true);
    try {
      const items = await listOAuthProviders(display);
      setProviders(items);
    } catch (e) {
      setError(errMsg(e));
    } finally {
      setLoading(false);
    }
  }, [display]);

  useEffect(() => {
    void load();
  }, [load]);

  const configuredProviders = useMemo(
    () => providers.filter((p) => p.client_id_configured),
    [providers],
  );

  const unconfiguredProviders = useMemo(
    () => providers.filter((p) => !p.client_id_configured),
    [providers],
  );

  const addDisabledReason = addClientIdDisabledReason(
    providers,
    unconfiguredProviders.length,
    loading,
  );

  return (
    <Stack spacing={1.5}>
      <Stack direction="row" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={1}>
        <Typography variant="subtitle1" fontWeight={600}>
          Account provider client IDs
        </Typography>
        {canWrite ? (
          <Button
            size="small"
            variant="contained"
            disabled={addDisabledReason != null}
            onClick={() => setAddOpen(true)}
          >
            Add client ID
          </Button>
        ) : null}
      </Stack>
      <Typography variant="body2" color="text.secondary">
        Some account providers (Google, Microsoft) require an OAuth app client ID before you can add
        a matching account below. Values are stored encrypted on the display and are never shown after
        saving. Application name and owner are looked up from the provider when possible.
      </Typography>
      {canWrite && addDisabledReason ? (
        <Typography variant="caption" color="text.secondary" display="block">
          {addDisabledReason}
        </Typography>
      ) : null}
      {error ? <Alert severity="error">{error}</Alert> : null}
      {loading ? (
        <Typography variant="body2" color="text.secondary">
          Loading account provider client IDs…
        </Typography>
      ) : configuredProviders.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          No account provider client IDs have been configured yet.
        </Typography>
      ) : (
        <TableContainer component={Paper} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Provider</TableCell>
                <TableCell>Application</TableCell>
                <TableCell>Owner</TableCell>
                <TableCell>Status</TableCell>
                {canWrite ? <TableCell align="right">Actions</TableCell> : null}
              </TableRow>
            </TableHead>
            <TableBody>
              {configuredProviders.map((provider) => {
                const meta = provider.client_id_metadata;
                return (
                  <TableRow key={provider.id} hover>
                    <TableCell sx={{ fontWeight: 600 }}>{provider.label}</TableCell>
                    <TableCell>
                      {meta?.application_name ?? (
                        <Typography variant="body2" color="text.secondary">
                          {meta?.lookup_status === 'error'
                            ? 'Lookup failed'
                            : meta?.lookup_status === 'unavailable'
                              ? 'Not available from provider'
                              : '—'}
                        </Typography>
                      )}
                    </TableCell>
                    <TableCell>
                      {meta?.owner ?? (
                        <Typography variant="body2" color="text.secondary">
                          —
                        </Typography>
                      )}
                    </TableCell>
                    <TableCell>
                      <Stack spacing={0.5}>
                        <Chip size="small" color="success" label="Configured" />
                        {meta?.lookup_status === 'error' && meta.lookup_error ? (
                          <Typography variant="caption" color="warning.main">
                            {meta.lookup_error}
                          </Typography>
                        ) : null}
                      </Stack>
                    </TableCell>
                    {canWrite ? (
                      <TableCell align="right">
                        <Button size="small" onClick={() => setReplaceProvider(provider)}>
                          Replace
                        </Button>
                      </TableCell>
                    ) : null}
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <ClientIdDialog
        open={addOpen}
        title="Add client ID"
        providers={unconfiguredProviders}
        onClose={() => setAddOpen(false)}
        onSaved={async () => {
          setAddOpen(false);
          await load();
        }}
        onError={setError}
        display={display}
      />
      <ClientIdDialog
        open={replaceProvider != null}
        title={replaceProvider ? `Replace ${replaceProvider.label} client ID` : 'Replace client ID'}
        providers={replaceProvider ? [replaceProvider] : []}
        onClose={() => setReplaceProvider(null)}
        onSaved={async () => {
          setReplaceProvider(null);
          await load();
        }}
        onError={setError}
        display={display}
      />
    </Stack>
  );
}

function ClientIdDialog({
  open,
  title,
  providers,
  onClose,
  onSaved,
  onError,
  display,
}: {
  open: boolean;
  title: string;
  providers: OAuthProviderStatus[];
  onClose: () => void;
  onSaved: () => Promise<void>;
  onError: (msg: string) => void;
  display: SavedDisplay;
}) {
  const [providerId, setProviderId] = useState('');
  const [clientId, setClientId] = useState('');
  const [busy, setBusy] = useState(false);

  const selected = providers.find((p) => p.id === providerId);
  const showProviderPicker = providers.length > 1;

  useEffect(() => {
    if (!open) return;
    setProviderId(providers[0]?.id ?? '');
    setClientId('');
  }, [open, providers]);

  const save = async () => {
    if (!selected) return;
    const value = clientId.trim();
    if (!value) {
      onError('Enter a client ID before saving.');
      return;
    }
    setBusy(true);
    try {
      await putOAuthProviderClientId(display, selected.id, value);
      await onSaved();
    } catch (e) {
      onError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>{title}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {providers.length === 0 ? (
            <Alert severity="info">All account provider client IDs are already configured.</Alert>
          ) : (
            <>
              {showProviderPicker ? (
                <FormControl fullWidth>
                  <InputLabel id="oauth-provider-label">Provider</InputLabel>
                  <Select
                    labelId="oauth-provider-label"
                    label="Provider"
                    value={providerId}
                    onChange={(e) => setProviderId(e.target.value)}
                  >
                    {providers.map((p) => (
                      <MenuItem key={p.id} value={p.id}>
                        {p.label}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              ) : selected ? (
                <Typography variant="body2" color="text.secondary">
                  Provider: <strong>{selected.label}</strong>
                </Typography>
              ) : null}
              <TextField
                label={`${selected?.label ?? 'OAuth'} client ID`}
                value={clientId}
                onChange={(e) => setClientId(e.target.value)}
                fullWidth
                autoFocus
                placeholder="Paste client ID from your cloud app registration"
              />
              <Typography variant="caption" color="text.secondary">
                After saving, the display will try to resolve the application name and owner from
                the provider.
              </Typography>
            </>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button
          variant="contained"
          disabled={busy || providers.length === 0 || clientId.trim().length === 0}
          onClick={() => void save()}
        >
          Save client ID
        </Button>
      </DialogActions>
    </Dialog>
  );
}
