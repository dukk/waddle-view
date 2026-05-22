import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Button,
  Chip,
  Link,
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
  createIntegrationAccount,
  deleteIntegrationAccount,
  fetchIntegrationAccounts,
  patchIntegrationAccount,
  probeIntegrationAccountOAuth,
  putIntegrationAccountSecret,
} from '@/api/integrationAccounts';
import { listOAuthProviders, type OAuthProviderStatus } from '@/api/oauthProviders';
import { completeDialogSave } from '@/util/dialogSave';
import { useConfirmDialog } from '@/hooks/useConfirmDialog';
import { integrationAccountIdFromName } from '@/util/integrationAccountSlug';
import type { SavedDisplay } from '@/storage/displays';
import {
  defaultIntegrationAccountLabel,
  type IntegrationAccountRow,
  type IntegrationAccountType,
} from '@/util/integrationAccounts';
import { integrationDisplayName } from '@/util/integrationDisplayName';

type AddableAccountType = IntegrationAccountType & {
  oauthProvider?: OAuthProviderStatus;
};

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

async function retryOAuthSignIn(
  display: SavedDisplay,
  accountId: string,
  reload: () => Promise<void>,
  onError: (msg: string) => void,
): Promise<void> {
  try {
    await probeIntegrationAccountOAuth(display, accountId);
    await reload();
  } catch (e) {
    onError(errMsg(e));
  }
}

export function IntegrationAccountsSection({
  display,
  canWrite,
}: {
  display: SavedDisplay;
  canWrite: boolean;
}) {
  const [accounts, setAccounts] = useState<IntegrationAccountRow[]>([]);
  const [accountTypes, setAccountTypes] = useState<IntegrationAccountType[]>([]);
  const [oauthProviders, setOauthProviders] = useState<OAuthProviderStatus[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [addAccountOpen, setAddAccountOpen] = useState(false);
  const [configureAccount, setConfigureAccount] = useState<IntegrationAccountRow | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const [accountsRes, providers] = await Promise.all([
        fetchIntegrationAccounts(display),
        listOAuthProviders(display),
      ]);
      setAccounts(accountsRes.items ?? []);
      setAccountTypes(accountsRes.account_types ?? []);
      setOauthProviders(providers);
    } catch (e) {
      setError(errMsg(e));
    }
  }, [display]);

  useEffect(() => {
    void load();
  }, [load]);

  const hasPendingOAuthSignIn = useMemo(
    () =>
      accounts.some(
        (a) => !a.configured && a.oauth_sign_in_status === 'pending',
      ),
    [accounts],
  );

  useEffect(() => {
    if (!hasPendingOAuthSignIn) {
      return;
    }
    const id = window.setInterval(() => {
      void load();
    }, 5000);
    return () => window.clearInterval(id);
  }, [hasPendingOAuthSignIn, load]);

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

  return (
    <Stack spacing={1.5}>
      <Stack direction="row" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={1}>
        <Typography variant="subtitle1" fontWeight={600}>
          Accounts & API keys
        </Typography>
        {canWrite ? (
          <Button size="small" variant="contained" onClick={() => setAddAccountOpen(true)}>
            Add account
          </Button>
        ) : null}
      </Stack>
      <Typography variant="body2" color="text.secondary">
        Shared sign-in identities and provider API keys used by integrations on this display.
      </Typography>
      {error ? (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      ) : null}
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
                      <Chip
                        size="small"
                        color="warning"
                        label={
                          account.oauth_sign_in_status === 'expired'
                            ? 'Sign-in expired'
                            : 'Sign-in pending'
                        }
                      />
                    ) : (
                      <Chip size="small" color="warning" label="Key needed" />
                    )}
                  </TableCell>
                  {canWrite ? (
                    <TableCell align="right">
                      <Stack direction="row" spacing={0.5} justifyContent="flex-end">
                        {!account.configured && account.supports_oauth_sign_in ? (
                          <Button
                            size="small"
                            variant="outlined"
                            onClick={() => void retryOAuthSignIn(display, account.id, load, setError)}
                          >
                            Retry sign-in
                          </Button>
                        ) : null}
                        <Button size="small" onClick={() => setConfigureAccount(account)}>
                          {account.configured ? 'Manage' : 'Configure'}
                        </Button>
                      </Stack>
                    </TableCell>
                  ) : null}
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <AddAccountDialog
        open={addAccountOpen}
        accountTypes={addableAccountTypes}
        existingAccountIds={accounts.map((a) => a.id)}
        onClose={() => setAddAccountOpen(false)}
        onSaved={async () => {
          setAddAccountOpen(false);
          await load();
        }}
        onError={setError}
        display={display}
      />
      <ConfigureAccountDialog
        open={configureAccount != null}
        account={configureAccount}
        onClose={() => setConfigureAccount(null)}
        onSaved={async () => {
          setConfigureAccount(null);
          await load();
        }}
        onReload={load}
        onError={setError}
        display={display}
      />
    </Stack>
  );
}

function AddAccountDialog({
  open,
  accountTypes,
  existingAccountIds,
  onClose,
  onSaved,
  onError,
  display,
}: {
  open: boolean;
  accountTypes: AddableAccountType[];
  existingAccountIds: string[];
  onClose: () => void;
  onSaved: () => Promise<void>;
  onError: (msg: string) => void;
  display: SavedDisplay;
}) {
  const [accountTypeId, setAccountTypeId] = useState('');
  const [name, setName] = useState('');
  const [apiKey, setApiKey] = useState('');
  const [busy, setBusy] = useState(false);

  const selected = accountTypes.find((t) => t.id === accountTypeId);
  const accountSlug = useMemo(
    () => integrationAccountIdFromName(name, existingAccountIds),
    [name, existingAccountIds],
  );

  useEffect(() => {
    if (!open) return;
    const first = accountTypes[0];
    setAccountTypeId(first?.id ?? '');
    setApiKey('');
  }, [open, accountTypes]);

  useEffect(() => {
    if (!open) return;
    const type = accountTypes.find((t) => t.id === accountTypeId);
    setName(type ? defaultIntegrationAccountLabel(type.label) : '');
  }, [open, accountTypeId, accountTypes]);

  const save = async () => {
    if (!selected) return;
    const trimmedName = name.trim();
    if (!trimmedName) {
      onError('Enter an account name.');
      return;
    }
    if (!accountSlug) {
      onError('Could not derive an account id from that name.');
      return;
    }
    setBusy(true);
    try {
      const { account_id } = await createIntegrationAccount(display, {
        account_type: selected.id,
        account_key: accountSlug,
        label: trimmedName,
      });
      if (selected.supports_oauth_sign_in) {
        await probeIntegrationAccountOAuth(display, account_id);
      } else {
        const key = apiKey.trim();
        if (!key) {
          onError('Enter an API key before saving.');
          return;
        }
        await putIntegrationAccountSecret(display, account_id, key);
      }
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      onError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  const canSubmit =
    selected != null &&
    name.trim().length > 0 &&
    accountSlug.length > 0 &&
    (selected.supports_oauth_sign_in || apiKey.trim().length > 0);

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>Add account</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {accountTypes.length === 0 ? (
            <Alert severity="info">
              No account types are available. Add OAuth client IDs above first, or ensure
              integrations are seeded on the display.
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
              <TextField
                label="Account name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                fullWidth
                required
              />
              {selected?.supports_oauth_sign_in ? (
                <Alert severity="info">
                  After saving, complete sign-in on the display when the device-code alert appears.
                </Alert>
              ) : (
                <>
                  {selected?.signup_url ? (
                    <Typography variant="body2">
                      <Link
                        href={selected.signup_url}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        Get an API key
                      </Link>
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
  onReload,
  onError,
  display,
}: {
  open: boolean;
  account: IntegrationAccountRow | null;
  onClose: () => void;
  onSaved: () => Promise<void>;
  onReload: () => Promise<void>;
  onError: (msg: string) => void;
  display: SavedDisplay;
}) {
  const { confirm, ConfirmDialogHost } = useConfirmDialog();
  const [name, setName] = useState('');
  const [apiKeyDraft, setApiKeyDraft] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (open && account) {
      setName(account.label);
      setApiKeyDraft('');
    }
  }, [open, account]);

  if (!account) {
    return null;
  }

  const saveDetails = async () => {
    const trimmedName = name.trim();
    if (!trimmedName) {
      onError('Enter an account name.');
      return;
    }
    setBusy(true);
    try {
      if (trimmedName !== account.label) {
        await patchIntegrationAccount(display, account.id, { label: trimmedName });
      }
      if (!account.supports_oauth_sign_in) {
        const key = apiKeyDraft.trim();
        if (key.length > 0) {
          await putIntegrationAccountSecret(display, account.id, key);
        }
      }
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      onError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  const requestSignIn = async () => {
    setBusy(true);
    try {
      await probeIntegrationAccountOAuth(display, account.id);
      await onReload();
    } catch (e) {
      onError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  const deleteAccount = async () => {
    const ok = await confirm({
      title: 'Delete account?',
      message: `Delete account "${account.label}"? This cannot be undone.`,
      confirmLabel: 'Delete',
      severity: 'error',
    });
    if (!ok) {
      return;
    }
    setBusy(true);
    try {
      await deleteIntegrationAccount(display, account.id, { confirm: true });
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      onError(errMsg(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>{account.account_type_label}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          <TextField
            label="Account name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            fullWidth
          />
          {account.supports_oauth_sign_in ? (
            <>
              <Typography variant="body2" color="text.secondary">
                Complete sign-in on the display (device code alert). If the code expired,
                use Retry sign-in to show a new prompt.
              </Typography>
              {account.signup_url ? (
                <Typography variant="body2">
                  <Link href={account.signup_url} target="_blank" rel="noopener noreferrer">
                    Create an account
                  </Link>
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
                Retry sign-in on display
              </Button>
            </>
          ) : (
            <>
              <Typography variant="body2" color="text.secondary">
                Enter the API key or token. It is stored encrypted on the display.
              </Typography>
              {account.signup_url ? (
                <Typography variant="body2">
                  <Link href={account.signup_url} target="_blank" rel="noopener noreferrer">
                    Get an API key
                  </Link>
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
      <DialogActions sx={{ justifyContent: 'space-between', px: 3, pb: 2 }}>
        <Button color="error" disabled={busy} onClick={() => void deleteAccount()}>
          Delete account
        </Button>
        <Stack direction="row" spacing={1}>
          <Button onClick={onClose}>Close</Button>
          <Button
            variant="contained"
            disabled={busy || name.trim().length === 0}
            onClick={() => void saveDetails()}
          >
            Save
          </Button>
        </Stack>
      </DialogActions>
    </Dialog>
    <ConfirmDialogHost />
    </>
  );
}
