import { useCallback, useState } from 'react';
import {
  Alert,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import type { SavedDisplay } from '@/storage/displays';
import { apiFetch, ApiError } from '@/api/client';
import type { IntegrationRequiredAccountType } from '@/util/integrationAccounts';
import {
  statusForRequiredAccountType,
  type IntegrationAccountsDetail,
  type IntegrationLinkedAccount,
} from '@/util/integrationAccountStatus';

type ConfigureTarget = {
  account: IntegrationLinkedAccount;
  requiredType: IntegrationRequiredAccountType;
};

function chipColor(status: 'available' | 'pending' | 'missing'): 'success' | 'warning' | 'default' {
  switch (status) {
    case 'available':
      return 'success';
    case 'pending':
      return 'warning';
    default:
      return 'default';
  }
}

function chipLabel(
  requiredType: IntegrationRequiredAccountType,
  status: 'available' | 'pending' | 'missing',
): string {
  const base = requiredType.account_type_label;
  switch (status) {
    case 'available':
      return `${base} ready`;
    case 'pending':
      return `${base} needs setup`;
    default:
      return `${base} not linked`;
  }
}

export function IntegrationAccountChips({
  display,
  detail,
  onChanged,
  compact = false,
}: {
  display: SavedDisplay;
  detail: IntegrationAccountsDetail | null;
  onChanged: () => Promise<void>;
  compact?: boolean;
}) {
  const [configure, setConfigure] = useState<ConfigureTarget | null>(null);
  const [apiKeyDraft, setApiKeyDraft] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const requestSignIn = useCallback(
    async (accountId: string) => {
      setBusy(true);
      setErr(null);
      try {
        await apiFetch(
          display,
          `/v1/integration-accounts/${encodeURIComponent(accountId)}/request-sign-in`,
          { method: 'POST' },
        );
        setConfigure(null);
        await onChanged();
      } catch (e) {
        setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      } finally {
        setBusy(false);
      }
    },
    [display, onChanged],
  );

  if (!detail || detail.required_account_types.length === 0) {
    return null;
  }

  const openConfigure = (requiredType: IntegrationRequiredAccountType) => {
    const linked = detail.linked_accounts.find((a) => a.account_type === requiredType.account_type);
    if (!linked) {
      return;
    }
    setApiKeyDraft('');
    setErr(null);
    setConfigure({ account: linked, requiredType });
  };

  const saveApiKey = async () => {
    if (!configure) return;
    setBusy(true);
    setErr(null);
    try {
      await apiFetch(
        display,
        `/v1/integration-accounts/${encodeURIComponent(configure.account.account_id)}/secrets/access_token`,
        {
          method: 'PUT',
          body: JSON.stringify({ value: apiKeyDraft.trim() }),
        },
      );
      setConfigure(null);
      await onChanged();
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Stack spacing={compact ? 0.5 : 1}>
      {!compact ? (
        <Typography variant="caption" color="text.secondary">
          Accounts
        </Typography>
      ) : null}
      <Stack direction="row" flexWrap="wrap" useFlexGap spacing={0.5}>
        {detail.required_account_types.map((requiredType) => {
          const status = statusForRequiredAccountType(detail, requiredType.account_type);
          const linked = detail.linked_accounts.find(
            (a) => a.account_type === requiredType.account_type,
          );
          const canConfigure = linked != null;
          return (
            <Chip
              key={requiredType.account_type}
              size="small"
              color={chipColor(status)}
              variant={status === 'available' ? 'filled' : 'outlined'}
              label={chipLabel(requiredType, status)}
              onClick={canConfigure ? () => openConfigure(requiredType) : undefined}
              clickable={canConfigure}
            />
          );
        })}
      </Stack>
      {detail.required_account_types.some(
        (t) => statusForRequiredAccountType(detail, t.account_type) === 'missing',
      ) ? (
        <Typography variant="caption" color="text.secondary">
          Add account keys under Configuration below, save, then complete sign-in or enter API
          keys.
        </Typography>
      ) : null}

      <Dialog
        open={configure != null}
        onClose={() => setConfigure(null)}
        fullWidth
        maxWidth="sm"
      >
        <DialogTitle>
          {configure?.requiredType.account_type_label ?? 'Account'}
        </DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            {err ? <Alert severity="error">{err}</Alert> : null}
            {configure?.account.supports_oauth_sign_in ? (
              <>
                <Typography variant="body2">
                  Account <strong>{configure.account.label}</strong> uses OAuth. Save this
                  integration, then complete sign-in on the display (device code alert), or request
                  a new sign-in prompt below.
                </Typography>
                {configure.requiredType.signup_url ? (
                  <Typography variant="body2">
                    Need an account?{' '}
                    <a
                      href={configure.requiredType.signup_url}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      Create one
                    </a>
                  </Typography>
                ) : null}
                <Button
                  variant="contained"
                  disabled={busy || configure.account.configured}
                  onClick={() => void requestSignIn(configure.account.account_id)}
                >
                  Request sign-in on display
                </Button>
                {configure.account.configured ? (
                  <Alert severity="success">This account is already signed in.</Alert>
                ) : null}
              </>
            ) : (
              <>
                <Typography variant="body2">
                  Enter the API key or token for <strong>{configure?.account.label}</strong>. It is
                  stored encrypted on the display.
                </Typography>
                {configure?.requiredType.signup_url ? (
                  <Typography variant="body2">
                    <a
                      href={configure.requiredType.signup_url}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      Get an API key
                    </a>
                  </Typography>
                ) : null}
                <TextField
                  type="password"
                  autoComplete="new-password"
                  label={configure?.requiredType.account_type_label}
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
          <Button onClick={() => setConfigure(null)}>Close</Button>
          {configure && !configure.account.supports_oauth_sign_in ? (
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
    </Stack>
  );
}
