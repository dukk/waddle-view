import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
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
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { ApiError } from '@/api/client';
import {
  createIntegrationAccount,
  fetchIntegrationAccounts,
  putIntegrationAccountSecret,
  requestIntegrationAccountSignIn,
} from '@/api/integrationAccounts';
import { listOAuthProviders, type OAuthProviderStatus } from '@/api/oauthProviders';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { integrationDisplayName } from '@/util/integrationDisplayName';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import type { SavedDisplay } from '@/storage/displays';
import type {
  IntegrationAccountRow,
  IntegrationAccountType,
} from '@/util/integrationAccounts';

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

type AddableAccountType = IntegrationAccountType & {
  oauthProvider?: OAuthProviderStatus;
};

export function IntegrationsPage() {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const canWrite = hasPermission('integrations.write');
  const { loading, wrapRefresh } = useDisplayRefresh();

  const [accounts, setAccounts] = useState<IntegrationAccountRow[]>([]);
  const [accountTypes, setAccountTypes] = useState<IntegrationAccountType[]>([]);
  const [oauthProviders, setOauthProviders] = useState<OAuthProviderStatus[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [configureAccount, setConfigureAccount] = useState<IntegrationAccountRow | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const [accountsRes, providers] = await Promise.all([
          fetchIntegrationAccounts(active),
          listOAuthProviders(active),
        ]);
        setAccounts(accountsRes.items ?? []);
        setAccountTypes(accountsRes.account_types ?? []);
        setOauthProviders(providers);
      } catch (e) {
        setError(errMsg(e));
      }
    });
  }, [active, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load]);

  const oauthConfiguredByAccountType = useMemo(() => {
    const map = new Map<string, boolean>();
    for (const p of oauthProviders) {
      map.set(p.account_type, p.client_id_configured);
    }
    return map;
  }, [oauthProviders]);

  const addableAccountTypes = useMemo((): AddableAccountType[] => {
    return accountTypes
      .filter((t) => {
        if (t.supports_oauth_sign_in) {
          return oauthConfiguredByAccountType.get(t.id) === true;
        }
        return true;
      })
      .map((t) => ({
        ...t,
        oauthProvider: oauthProviders.find((p) => p.account_type === t.id),
      }));
  }, [accountTypes, oauthConfiguredByAccountType, oauthProviders]);

  if (!active) {
    return <NoDisplayPlaceholder title="Integrations" />;
  }

  return (
    <Stack spacing={3}>
      <DisplayRefreshIndicator loading={loading} />
      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          Accounts & API keys
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Shared sign-in identities and provider API keys used by collectors. Add OAuth client IDs
          under <strong>Display settings → Integrations</strong> before adding Google or Microsoft
          accounts.
        </Typography>
      </Box>

      {error ? (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      ) : null}

      <Stack direction="row" justifyContent="flex-end">
        {canWrite ? (
          <Button variant="contained" onClick={() => setAddOpen(true)}>
            Add account
          </Button>
        ) : null}
      </Stack>

      {accounts.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          No accounts or API keys have been added yet.
        </Typography>
      ) : (
        <TableContainer component={Paper} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Account</TableCell>
                <TableCell>Type</TableCell>
                <TableCell>Used by</TableCell>
                <TableCell>Status</TableCell>
                {canWrite ? <TableCell align="right">Actions</TableCell> : null}
              </TableRow>
            </TableHead>
            <TableBody>
              {accounts.map((account) => (
                <TableRow key={`${account.account_type}:${account.id}`} hover>
                  <TableCell sx={{ fontWeight: 600 }}>{account.label}</TableCell>
                  <TableCell>{account.account_type_label}</TableCell>
                  <TableCell>
                    <Stack direction="row" flexWrap="wrap" useFlexGap spacing={0.5}>
                      {account.integration_types.map((t) => (
                        <Chip
                          key={t}
                          size="small"
                          label={integrationDisplayName(t)}
                          variant="outlined"
                        />
                      ))}
                    </Stack>
                  </TableCell>
                  <TableCell>
                    {account.configured ? (
                      <Chip size="small" color="success" label="Ready" />
                    ) : account.supports_oauth_sign_in ? (
                      <Chip size="small" color="warning" label="Sign-in pending" />
                    ) : (
                      <Chip size="small" color="warning" label="Key needed" />
                    )}
                  </TableCell>
                  {canWrite ? (
                    <TableCell align="right">
                      <Button size="small" onClick={() => setConfigureAccount(account)}>
                        {account.configured ? 'Manage' : 'Configure'}
                      </Button>
                    </TableCell>
                  ) : null}
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <AddAccountDialog
        open={addOpen}
        accountTypes={addableAccountTypes}
        onClose={() => setAddOpen(false)}
        onSaved={async () => {
          setAddOpen(false);
          await load();
        }}
        onError={setError}
        display={active}
      />

      <ConfigureAccountDialog
        open={configureAccount != null}
        account={configureAccount}
        onClose={() => setConfigureAccount(null)}
        onSaved={async () => {
          setConfigureAccount(null);
          await load();
        }}
        onError={setError}
        display={active}
      />
    </Stack>
  );
}

function AddAccountDialog({
  open,
  accountTypes,
  onClose,
  onSaved,
  onError,
  display,
}: {
  open: boolean;
  accountTypes: AddableAccountType[];
  onClose: () => void;
  onSaved: () => Promise<void>;
  onError: (msg: string) => void;
  display: SavedDisplay;
}) {
  const [accountTypeId, setAccountTypeId] = useState('');
  const [accountKey, setAccountKey] = useState('');
  const [label, setLabel] = useState('');
  const [apiKey, setApiKey] = useState('');
  const [busy, setBusy] = useState(false);

  const selected = accountTypes.find((t) => t.id === accountTypeId);

  useEffect(() => {
    if (!open) return;
    const first = accountTypes[0];
    setAccountTypeId(first?.id ?? '');
    setAccountKey('');
    setLabel('');
    setApiKey('');
  }, [open, accountTypes]);

  const save = async () => {
    if (!selected) return;
    setBusy(true);
    try {
      const { account_id } = await createIntegrationAccount(display, {
        account_type: selected.id,
        account_key: selected.supports_oauth_sign_in ? accountKey.trim() : undefined,
        label: label.trim() || undefined,
      });
      if (selected.supports_oauth_sign_in) {
        await requestIntegrationAccountSignIn(display, account_id);
      } else {
        const key = apiKey.trim();
        if (!key) {
          onError('Enter an API key before saving.');
          return;
        }
        await putIntegrationAccountSecret(display, account_id, key);
      }
      await onSaved();
    } catch (e) {
      onError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  const canSubmit =
    selected != null &&
    (selected.supports_oauth_sign_in
      ? accountKey.trim().length > 0
      : apiKey.trim().length > 0);

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>Add account</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {accountTypes.length === 0 ? (
            <Alert severity="info">
              No account types are available. Configure OAuth client IDs under Display settings →
              Integrations, or ensure integrations are seeded on the display.
            </Alert>
          ) : (
            <>
              <FormControl fullWidth>
                <InputLabel id="add-account-type-label">Account type</InputLabel>
                <Select
                  labelId="add-account-type-label"
                  label="Account type"
                  value={accountTypeId}
                  onChange={(e) => setAccountTypeId(e.target.value)}
                >
                  {accountTypes.map((t) => (
                    <MenuItem key={t.id} value={t.id}>
                      {t.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
              {selected?.supports_oauth_sign_in ? (
                <>
                  <Typography variant="body2" color="text.secondary">
                    Choose a short id for this account (letters, numbers, underscores). It is
                    written into calendar and cloud integration config and used for sign-in on the
                    display.
                  </Typography>
                  <TextField
                    label="Account id"
                    value={accountKey}
                    onChange={(e) => setAccountKey(e.target.value)}
                    fullWidth
                    required
                  />
                  <TextField
                    label="Display label"
                    value={label}
                    onChange={(e) => setLabel(e.target.value)}
                    fullWidth
                  />
                  <Alert severity="info">
                    After saving, complete sign-in on the display when the device-code alert appears.
                  </Alert>
                </>
              ) : (
                <>
                  {selected?.signup_url ? (
                    <Typography variant="body2">
                      <a href={selected.signup_url} target="_blank" rel="noopener noreferrer">
                        Get an API key
                      </a>
                    </Typography>
                  ) : null}
                  <TextField
                    type="password"
                    autoComplete="new-password"
                    label={selected?.label ?? 'API key'}
                    value={apiKey}
                    onChange={(e) => setApiKey(e.target.value)}
                    fullWidth
                    required
                  />
                </>
              )}
            </>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button
          variant="contained"
          disabled={busy || !canSubmit || accountTypes.length === 0}
          onClick={() => void save()}
        >
          {selected?.supports_oauth_sign_in ? 'Add & request sign-in' : 'Save'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}

function ConfigureAccountDialog({
  open,
  account,
  onClose,
  onSaved,
  onError,
  display,
}: {
  open: boolean;
  account: IntegrationAccountRow | null;
  onClose: () => void;
  onSaved: () => Promise<void>;
  onError: (msg: string) => void;
  display: SavedDisplay;
}) {
  const [apiKeyDraft, setApiKeyDraft] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (open) {
      setApiKeyDraft('');
    }
  }, [open, account?.id]);

  if (!account) {
    return null;
  }

  const saveApiKey = async () => {
    setBusy(true);
    try {
      await putIntegrationAccountSecret(display, account.id, apiKeyDraft.trim());
      await onSaved();
    } catch (e) {
      onError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  const requestSignIn = async () => {
    setBusy(true);
    try {
      await requestIntegrationAccountSignIn(display, account.id);
      await onSaved();
    } catch (e) {
      onError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>{account.account_type_label}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          <Typography variant="body2">
            Account <strong>{account.label}</strong> ({account.id})
          </Typography>
          {account.supports_oauth_sign_in ? (
            <>
              <Typography variant="body2" color="text.secondary">
                Complete sign-in on the display (device code alert), or request a new prompt.
              </Typography>
              {account.signup_url ? (
                <Typography variant="body2">
                  <a href={account.signup_url} target="_blank" rel="noopener noreferrer">
                    Create an account
                  </a>
                </Typography>
              ) : null}
              {account.configured ? (
                <Alert severity="success">This account is signed in.</Alert>
              ) : null}
              <Button
                variant="contained"
                disabled={busy || account.configured}
                onClick={() => void requestSignIn()}
              >
                Request sign-in on display
              </Button>
            </>
          ) : (
            <>
              <Typography variant="body2" color="text.secondary">
                Enter the API key or token. It is stored encrypted on the display.
              </Typography>
              {account.signup_url ? (
                <Typography variant="body2">
                  <a href={account.signup_url} target="_blank" rel="noopener noreferrer">
                    Get an API key
                  </a>
                </Typography>
              ) : null}
              <TextField
                type="password"
                autoComplete="new-password"
                label={account.account_type_label}
                value={apiKeyDraft}
                onChange={(e) => setApiKeyDraft(e.target.value)}
                fullWidth
                size="small"
              />
            </>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Close</Button>
        {!account.supports_oauth_sign_in ? (
          <Button
            variant="contained"
            disabled={busy || apiKeyDraft.trim().length === 0}
            onClick={() => void saveApiKey()}
          >
            Save key
          </Button>
        ) : null}
      </DialogActions>
    </Dialog>
  );
}
