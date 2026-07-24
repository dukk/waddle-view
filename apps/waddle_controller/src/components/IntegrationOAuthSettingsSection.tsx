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
  Link,
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
import { completeDialogSave } from '@/util/dialogSave';
import { oauthClientIdRegistrationGuide } from '@/util/oauthClientIdRegistration';

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
      <Stack
        direction="row"
        sx={{
          justifyContent: "space-between",
          alignItems: "center",
          flexWrap: "wrap",
          gap: 1
        }}>
        <Typography variant="subtitle1" sx={{
          fontWeight: 600
        }}>
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
      <Typography variant="body2" sx={{
        color: "text.secondary"
      }}>
        OAuth account providers (Google, Microsoft, Facebook, X, LinkedIn) require an app client ID
        before you can add a matching account below. Values are stored encrypted on the display and are
        never shown after saving.
      </Typography>
      {canWrite && addDisabledReason ? (
        <Typography
          variant="caption"
          sx={{
            color: "text.secondary",
            display: "block"
          }}>
          {addDisabledReason}
        </Typography>
      ) : null}
      {error ? <Alert severity="error">{error}</Alert> : null}
      {loading ? (
        <Typography variant="body2" sx={{
          color: "text.secondary"
        }}>
          Loading account provider client IDs…
        </Typography>
      ) : configuredProviders.length === 0 ? (
        <Typography variant="body2" sx={{
          color: "text.secondary"
        }}>
          No account provider client IDs have been configured yet.
        </Typography>
      ) : (
        <TableContainer component={Paper} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Provider</TableCell>
                <TableCell>Status</TableCell>
                {canWrite ? <TableCell align="right">Actions</TableCell> : null}
              </TableRow>
            </TableHead>
            <TableBody>
              {configuredProviders.map((provider) => (
                <TableRow key={provider.id} hover>
                  <TableCell sx={{ fontWeight: 600 }}>{provider.label}</TableCell>
                  <TableCell>
                    <Chip size="small" color="success" label="Configured" />
                  </TableCell>
                  {canWrite ? (
                    <TableCell align="right">
                      <Button size="small" onClick={() => setReplaceProvider(provider)}>
                        Replace
                      </Button>
                    </TableCell>
                  ) : null}
                </TableRow>
              ))}
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
  const registrationGuide = selected
    ? oauthClientIdRegistrationGuide(selected.id)
    : undefined;
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
      await completeDialogSave(onSaved, onClose);
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
                <Typography variant="body2" sx={{
                  color: "text.secondary"
                }}>
                  Provider: <strong>{selected.label}</strong>
                </Typography>
              ) : null}
              {registrationGuide ? (
                <Typography variant="body2" sx={{
                  color: "text.secondary"
                }}>
                  {registrationGuide.message}{' '}
                  <Link
                    href={registrationGuide.href}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {registrationGuide.linkLabel}
                  </Link>
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
