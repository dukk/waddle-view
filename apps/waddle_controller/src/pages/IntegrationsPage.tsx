import { useCallback, useEffect, useMemo, useState } from 'react';
import type { IntegrationSecretSlot } from '@/util/integrationSecrets';
import { integrationSecretsSatisfiedForEnable } from '@/util/integrationSecrets';
import {
  Alert,
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
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
  Switch,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import Form from '@rjsf/mui';
import validator from '@rjsf/validator-ajv8';
import type { RJSFSchema } from '@rjsf/utils';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import {
  createIntegrationAccount,
  fetchIntegrationAccounts,
  patchIntegrationAccount,
  putIntegrationAccountSecret,
  probeIntegrationAccountOAuth,
} from '@/api/integrationAccounts';
import { integrationAccountIdFromName } from '@/util/integrationAccountSlug';
import { listOAuthProviders, type OAuthProviderStatus } from '@/api/oauthProviders';
import { CatalogPageToolbar } from '@/components/CatalogPageToolbar';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { IntegrationBrandIcon } from '@/components/IntegrationBrandIcon';
import { integrationDataFamily } from '@/util/integrationIcon';
import { parseJsonObject } from '@/util/json';
import { prepareRjsfSchema } from '@/util/rjsfSchema';
import { fetchIntegrationAccountsDetail } from '@/api/integrationAccounts';
import { IntegrationAccountChips } from '@/components/IntegrationAccountChips';
import type { SavedDisplay } from '@/storage/displays';
import type {
  IntegrationAccountRow,
  IntegrationAccountType,
  IntegrationRequiredAccountType,
} from '@/util/integrationAccounts';
import {
  integrationAccountsSatisfiedForEnable,
  type IntegrationAccountsDetail,
  type IntegrationLinkedAccount,
} from '@/util/integrationAccountStatus';
import { integrationDisplayName } from '@/util/integrationDisplayName';

type IntegrationRow = {
  id: string;
  integration_type: string;
  enabled: boolean;
  poll_seconds: number;
  base_url: string | null;
  config_json: unknown;
  config_json_schema?: unknown;
  example_config_json?: unknown;
  secrets_configured?: boolean;
  accounts_configured?: boolean;
  required_account_types?: IntegrationRequiredAccountType[];
  linked_accounts?: IntegrationLinkedAccount[];
};

function accountsDetailFromRow(row: IntegrationRow): IntegrationAccountsDetail | null {
  if ((row.required_account_types?.length ?? 0) === 0) {
    return null;
  }
  return {
    required_account_types: row.required_account_types ?? [],
    linked_accounts: row.linked_accounts ?? [],
    accounts_configured: row.accounts_configured ?? false,
  };
}

function integrationConfigSchema(row: IntegrationRow): RJSFSchema {
  return prepareRjsfSchema(row.config_json_schema);
}

function configJsonSatisfiesSchema(row: IntegrationRow): boolean {
  const schema = integrationConfigSchema(row);
  const formData = parseJsonObject(row.config_json);
  const { errors } = validator.validateFormData(formData, schema);
  return errors.length === 0;
}

function sortById(a: IntegrationRow, b: IntegrationRow): number {
  return a.id.localeCompare(b.id);
}

function familyLabel(family: string): string {
  if (family.length === 0) return 'Other';
  return family.charAt(0).toUpperCase() + family.slice(1);
}

/** Preferred chip order for known integration families; unknown families sort after these. */
const FAMILY_ORDER: readonly string[] = [
  'calendar',
  'joke',
  'media',
  'news',
  'stock',
  'trivia',
  'weather',
  'stub',
];

function compareFamilies(a: string, b: string): number {
  const ai = FAMILY_ORDER.indexOf(a);
  const bi = FAMILY_ORDER.indexOf(b);
  if (ai >= 0 && bi >= 0) return ai - bi;
  if (ai >= 0) return -1;
  if (bi >= 0) return 1;
  return a.localeCompare(b);
}

type AddableAccountType = IntegrationAccountType & {
  oauthProvider?: OAuthProviderStatus;
};

function OperatorAccountsSection({
  accounts,
  canWrite,
  onAdd,
  onConfigure,
}: {
  accounts: IntegrationAccountRow[];
  canWrite: boolean;
  onAdd: () => void;
  onConfigure: (account: IntegrationAccountRow) => void;
}) {
  return (
    <Stack spacing={1.5}>
      <Stack direction="row" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={1}>
        <Typography variant="subtitle1" fontWeight={600}>
          Accounts & API keys
        </Typography>
        {canWrite ? (
          <Button size="small" variant="contained" onClick={onAdd}>
            Add account
          </Button>
        ) : null}
      </Stack>
      <Typography variant="body2" color="text.secondary">
        Shared sign-in identities and provider API keys. Set Google and Microsoft OAuth client IDs
        under <strong>Display settings → Integrations</strong> before adding those account types.
      </Typography>
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
                      <Button size="small" onClick={() => onConfigure(account)}>
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
    </Stack>
  );
}

function IntegrationTable({
  rows,
  actionLabel,
  onAction,
}: {
  rows: IntegrationRow[];
  actionLabel: string;
  onAction: (row: IntegrationRow) => void;
}) {
  return (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Integration</TableCell>
            <TableCell>Poll interval</TableCell>
            <TableCell>Base URL</TableCell>
            <TableCell>Config</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row) => {
            const displayName = integrationDisplayName(row.integration_type);
            const configOk = configJsonSatisfiesSchema(row);
            const showConfigHint = actionLabel === 'Enable' && !configOk;
            return (
              <TableRow key={row.id} hover>
                <TableCell sx={{ fontWeight: 600 }}>{displayName}</TableCell>
                <TableCell>{row.poll_seconds}s</TableCell>
                <TableCell sx={{ maxWidth: 280, wordBreak: 'break-all', fontSize: '0.85rem' }}>
                  {row.base_url ?? ''}
                </TableCell>
                <TableCell>
                  {showConfigHint ? (
                    <Chip size="small" color="warning" label="Schema mismatch" />
                  ) : (
                    <Typography variant="body2" color="text.secondary">
                      OK
                    </Typography>
                  )}
                </TableCell>
                <TableCell align="right">
                  <Button size="small" variant="outlined" onClick={() => onAction(row)}>
                    {actionLabel}
                  </Button>
                </TableCell>
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

export function IntegrationsPage() {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const canWrite = hasPermission('integrations.write');
  const { loading, wrapRefresh } = useDisplayRefresh();
  const { layout, setLayout } = useListLayoutPreference('integrations');
  const [rows, setRows] = useState<IntegrationRow[]>([]);
  const [accounts, setAccounts] = useState<IntegrationAccountRow[]>([]);
  const [accountTypes, setAccountTypes] = useState<IntegrationAccountType[]>([]);
  const [oauthProviders, setOauthProviders] = useState<OAuthProviderStatus[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [edit, setEdit] = useState<IntegrationRow | null>(null);
  const [dialogIntent, setDialogIntent] = useState<'edit' | 'enable'>('edit');
  const [filterFamily, setFilterFamily] = useState<string | null>(null);
  const [addAccountOpen, setAddAccountOpen] = useState(false);
  const [configureAccount, setConfigureAccount] = useState<IntegrationAccountRow | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const [integrationsRes, accountsRes, providers] = await Promise.all([
          apiJson<{ items: IntegrationRow[] }>(active, '/v1/integrations'),
          fetchIntegrationAccounts(active),
          listOAuthProviders(active),
        ]);
        setRows(integrationsRes.items ?? []);
        setAccounts(accountsRes.items ?? []);
        setAccountTypes(accountsRes.account_types ?? []);
        setOauthProviders(providers);
      } catch (e) {
        setError(errMsg(e));
      }
    });
  }, [active, wrapRefresh]);

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

  useEffect(() => {
    void load();
  }, [load]);

  const familiesInUse = useMemo(() => {
    const set = new Set(rows.map((r) => integrationDataFamily(r.integration_type)));
    return [...set].sort(compareFamilies);
  }, [rows]);

  useEffect(() => {
    if (filterFamily != null && !familiesInUse.includes(filterFamily)) {
      setFilterFamily(null);
    }
  }, [filterFamily, familiesInUse]);

  const familyCounts = useMemo(() => {
    const m = new Map<string, number>();
    for (const r of rows) {
      const f = integrationDataFamily(r.integration_type);
      m.set(f, (m.get(f) ?? 0) + 1);
    }
    return m;
  }, [rows]);

  const filteredRows = useMemo(() => {
    if (filterFamily == null) return rows;
    return rows.filter((r) => integrationDataFamily(r.integration_type) === filterFamily);
  }, [rows, filterFamily]);

  const { enabledRows, disabledRows } = useMemo(() => {
    const enabled = filteredRows.filter((r) => r.enabled).sort(sortById);
    const disabled = filteredRows.filter((r) => !r.enabled).sort(sortById);
    return { enabledRows: enabled, disabledRows: disabled };
  }, [filteredRows]);

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={3}>
      <DisplayRefreshIndicator loading={loading} />
      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          External data sources
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Connect external data sources—calendars, news, weather, stocks, and more—that collectors
          poll into the display database. Add shared accounts and API keys below, then enable
          providers and complete each integration&apos;s configuration.
        </Typography>
      </Box>
      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <OperatorAccountsSection
        accounts={accounts}
        canWrite={canWrite}
        onAdd={() => setAddAccountOpen(true)}
        onConfigure={setConfigureAccount}
      />

      <CatalogPageToolbar layout={layout} onLayoutChange={setLayout} />

      <Stack spacing={1}>
        <Typography variant="subtitle2" color="text.secondary">
          Filter by data type
        </Typography>
        <Stack direction="row" flexWrap="wrap" useFlexGap spacing={1}>
          <Chip
            label={`All (${rows.length})`}
            onClick={() => setFilterFamily(null)}
            color={filterFamily === null ? 'primary' : 'default'}
            variant={filterFamily === null ? 'filled' : 'outlined'}
            clickable
          />
          {familiesInUse.map((family) => {
            const n = familyCounts.get(family) ?? 0;
            const selected = filterFamily === family;
            return (
              <Chip
                key={family}
                label={`${familyLabel(family)} (${n})`}
                onClick={() => setFilterFamily(family)}
                color={selected ? 'primary' : 'default'}
                variant={selected ? 'filled' : 'outlined'}
                clickable
              />
            );
          })}
        </Stack>
      </Stack>

      {filterFamily != null && filteredRows.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          No integrations match this filter.
        </Typography>
      ) : null}

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Enabled
        </Typography>
        {enabledRows.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            {filterFamily != null
              ? 'No enabled integrations match this filter.'
              : 'No integrations are enabled.'}
          </Typography>
        ) : layout === 'card' ? (
          <Box sx={catalogCardGridSx}>
            {enabledRows.map((r) => (
              <IntegrationCard
                key={r.id}
                row={r}
                actionLabel="Edit"
                onAccountsChanged={load}
                onAction={() => {
                  setDialogIntent('edit');
                  setEdit(r);
                }}
              />
            ))}
          </Box>
        ) : (
          <IntegrationTable
            rows={enabledRows}
            actionLabel="Edit"
            onAction={(r) => {
              setDialogIntent('edit');
              setEdit(r);
            }}
          />
        )}
      </Stack>

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Available to enable
        </Typography>
        {disabledRows.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            {filterFamily != null
              ? 'No disabled integrations match this filter.'
              : 'All integrations are enabled.'}
          </Typography>
        ) : layout === 'card' ? (
          <Box sx={catalogCardGridSx}>
            {disabledRows.map((r) => (
              <IntegrationCard
                key={r.id}
                row={r}
                actionLabel="Enable"
                onAccountsChanged={load}
                onAction={() => {
                  setDialogIntent('enable');
                  setEdit(r);
                }}
              />
            ))}
          </Box>
        ) : (
          <IntegrationTable
            rows={disabledRows}
            actionLabel="Enable"
            onAction={(r) => {
              setDialogIntent('enable');
              setEdit(r);
            }}
          />
        )}
      </Stack>

      {edit && (
        <EditIntegrationDialog
          row={edit}
          intent={dialogIntent}
          oauthProviders={oauthProviders}
          onClose={() => setEdit(null)}
          onSaved={async () => {
            setEdit(null);
            await load();
          }}
        />
      )}

      {active && (
        <>
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
        </>
      )}
    </Stack>
  );
}

function IntegrationCard({
  row,
  actionLabel,
  onAction,
  onAccountsChanged,
}: {
  row: IntegrationRow;
  actionLabel: string;
  onAction: () => void;
  onAccountsChanged?: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const displayName = integrationDisplayName(row.integration_type);
  const accountDetail = accountsDetailFromRow(row);

  return (
    <Card
      variant="outlined"
      sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}
      aria-label={`${displayName} integration`}
    >
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Stack direction="row" spacing={1.5} alignItems="flex-start">
            <IntegrationBrandIcon
              integrationType={row.integration_type}
              baseUrl={row.base_url}
            />
            <Typography
              variant="subtitle1"
              fontWeight={600}
              sx={{ wordBreak: 'break-word', flex: 1, minWidth: 0, pt: 0.25 }}
            >
              {displayName}
            </Typography>
          </Stack>
          <Typography variant="caption" color="text.secondary" display="block">
            Poll every {row.poll_seconds}s
          </Typography>
          {row.base_url ? (
            <Typography variant="caption" color="text.secondary" sx={{ wordBreak: 'break-all' }}>
              {row.base_url}
            </Typography>
          ) : null}
          {active && accountDetail ? (
            <IntegrationAccountChips
              display={active}
              detail={accountDetail}
              onChanged={onAccountsChanged ?? (async () => {})}
              compact
            />
          ) : null}
        </Stack>
      </CardContent>
      <CardActions sx={{ justifyContent: 'flex-end', px: 2, pb: 2 }}>
        <Button size="small" variant="outlined" onClick={onAction}>
          {actionLabel}
        </Button>
      </CardActions>
    </Card>
  );
}

function EditIntegrationDialog({
  row,
  intent,
  oauthProviders,
  onClose,
  onSaved,
}: {
  row: IntegrationRow;
  intent: 'edit' | 'enable';
  oauthProviders: OAuthProviderStatus[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const schema = useMemo(() => integrationConfigSchema(row), [row]);
  const [enabled, setEnabled] = useState(() => (intent === 'enable' ? true : row.enabled));
  const [poll, setPoll] = useState(row.poll_seconds);
  const [baseUrl, setBaseUrl] = useState(row.base_url ?? '');
  const [formData, setFormData] = useState<Record<string, unknown>>(() =>
    parseJsonObject(row.config_json),
  );
  const [secretSlots, setSecretSlots] = useState<IntegrationSecretSlot[]>([]);
  const [secretDrafts, setSecretDrafts] = useState<Record<string, string>>({});
  const [secretsLoading, setSecretsLoading] = useState(true);
  const [accountDetail, setAccountDetail] = useState<IntegrationAccountsDetail | null>(
    () => accountsDetailFromRow(row),
  );
  const [accountsLoading, setAccountsLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  const reloadAccounts = useCallback(async () => {
    if (!active) return;
    setAccountsLoading(true);
    try {
      const detail = await fetchIntegrationAccountsDetail(active, row.id);
      setAccountDetail(detail);
    } catch {
      setAccountDetail(accountsDetailFromRow(row));
    } finally {
      setAccountsLoading(false);
    }
  }, [active, row]);

  useEffect(() => {
    void reloadAccounts();
  }, [reloadAccounts]);

  useEffect(() => {
    if (!active) return;
    let cancelled = false;
    void (async () => {
      setSecretsLoading(true);
      try {
        const res = await apiJson<{ slots: IntegrationSecretSlot[] }>(
          active,
          `/v1/integrations/${encodeURIComponent(row.id)}/secrets`,
        );
        if (!cancelled) {
          setSecretSlots((res.slots ?? []).filter((s) => s.id !== 'client_id'));
        }
      } catch {
        if (!cancelled) {
          setSecretSlots([]);
        }
      } finally {
        if (!cancelled) {
          setSecretsLoading(false);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [active, row.id]);

  const oauthClientIdsReady = useMemo(() => {
    const oauthTypes =
      row.required_account_types?.filter((t) => t.supports_oauth_sign_in) ?? [];
    if (oauthTypes.length === 0) {
      return true;
    }
    return oauthTypes.every((t) => {
      const provider = oauthProviders.find((p) => p.account_type === t.account_type);
      return provider?.client_id_configured === true;
    });
  }, [row.required_account_types, oauthProviders]);

  const secretsReady = useMemo(
    () =>
      oauthClientIdsReady &&
      integrationSecretsSatisfiedForEnable(secretSlots, secretDrafts),
    [oauthClientIdsReady, secretSlots, secretDrafts],
  );

  const accountsReady = useMemo(
    () => integrationAccountsSatisfiedForEnable(accountDetail),
    [accountDetail],
  );

  const displayName = useMemo(
    () => integrationDisplayName(row.integration_type),
    [row.integration_type],
  );

  const save = async () => {
    if (!active) return;
    setErr(null);
    if (enabled) {
      const { errors } = validator.validateFormData(formData, schema);
      if (errors.length > 0) {
        setErr(errors.map((e) => e.stack ?? e.message ?? 'Invalid field').join('\n'));
        return;
      }
    }
    if (poll <= 0) {
      setErr('Poll seconds must be greater than zero.');
      return;
    }
    if (enabled && !oauthClientIdsReady) {
      setErr(
        'Configure required OAuth client IDs under Display settings → Integrations before enabling.',
      );
      return;
    }
    if (enabled && !integrationSecretsSatisfiedForEnable(secretSlots, secretDrafts)) {
      setErr('Configure all required integration secrets before enabling.');
      return;
    }
    if (enabled && !accountsReady) {
      setErr('Configure all required accounts before enabling this integration.');
      return;
    }
    try {
      for (const slot of secretSlots) {
        const draft = (secretDrafts[slot.id] ?? '').trim();
        if (draft.length > 0) {
          await apiFetch(
            active,
            `/v1/integrations/${encodeURIComponent(row.id)}/secrets/${encodeURIComponent(slot.id)}`,
            {
              method: 'PUT',
              body: JSON.stringify({ value: draft }),
            },
          );
        }
      }
      await apiFetch(active, `/v1/integrations/${encodeURIComponent(row.id)}`, {
        method: 'PATCH',
        body: JSON.stringify({
          enabled,
          poll_seconds: poll,
          base_url: baseUrl.trim() || null,
          config_json: formData,
        }),
      });
      await reloadAccounts();
      await onSaved();
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  const title = intent === 'enable' ? `Enable ${displayName}` : `Edit ${displayName}`;

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="md">
      <DialogTitle>
        <Stack direction="row" spacing={1.5} alignItems="center">
          <IntegrationBrandIcon
            integrationType={row.integration_type}
            baseUrl={row.base_url}
            size={32}
          />
          <span>{title}</span>
        </Stack>
      </DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {err && <Alert severity="error">{err}</Alert>}
          <Stack direction="row" alignItems="center" spacing={1}>
            <Switch
              checked={enabled}
              onChange={(_, v) => setEnabled(v)}
              disabled={
                enabled === false &&
                ((secretSlots.length > 0 && !secretsReady) || !accountsReady)
              }
            />
            <Typography>Enabled</Typography>
          </Stack>
          {!oauthClientIdsReady ? (
            <Alert severity="info">
              Set OAuth client IDs under <strong>Display settings → Integrations</strong> before
              enabling.
            </Alert>
          ) : null}
          {accountsLoading ? (
            <Typography variant="body2" color="text.secondary">
              Loading accounts…
            </Typography>
          ) : active && accountDetail ? (
            <IntegrationAccountChips
              display={active}
              detail={accountDetail}
              onChanged={reloadAccounts}
            />
          ) : null}
          {!accountsReady && accountDetail ? (
            <Alert severity="info">
              Add accounts in the section above, or link account keys in Configuration below, then
              complete sign-in or API keys.
            </Alert>
          ) : null}
          {secretsLoading ? (
            <Typography variant="body2" color="text.secondary">
              Loading secrets…
            </Typography>
          ) : secretSlots.length > 0 ? (
            <Stack spacing={1.5}>
              <Typography variant="subtitle2">Secrets (stored on display)</Typography>
              {secretSlots.map((slot) => (
                <Stack key={slot.id} spacing={0.5}>
                  <Stack direction="row" alignItems="center" spacing={1}>
                    <Typography variant="body2">{slot.label}</Typography>
                    {slot.configured ? (
                      <Chip size="small" color="success" label="Configured" />
                    ) : (
                      <Chip size="small" color="warning" label="Required" />
                    )}
                  </Stack>
                  <TextField
                    type="password"
                    autoComplete="new-password"
                    placeholder={
                      slot.configured ? 'Leave blank to keep current value' : 'Enter value'
                    }
                    value={secretDrafts[slot.id] ?? ''}
                    onChange={(e) =>
                      setSecretDrafts((prev) => ({ ...prev, [slot.id]: e.target.value }))
                    }
                    fullWidth
                    size="small"
                  />
                </Stack>
              ))}
            </Stack>
          ) : null}
          <TextField
            label="Poll seconds"
            type="number"
            value={poll}
            onChange={(e) => setPoll(Number(e.target.value) || 0)}
            fullWidth
          />
          <TextField
            label="Base URL"
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            fullWidth
          />
          <Typography variant="subtitle2">Configuration (config_json)</Typography>
          <Box sx={{ '& .MuiFormControl-root': { mb: 1 } }}>
            <Form
              schema={schema}
              formData={formData}
              validator={validator}
              onChange={(e) => setFormData(e.formData as Record<string, unknown>)}
            >
              <Box sx={{ display: 'none' }}>
                <button type="submit" />
              </Box>
            </Form>
          </Box>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button
          variant="contained"
          onClick={() => void save()}
          disabled={poll <= 0 || (enabled && (!secretsReady || !accountsReady))}
        >
          Save
        </Button>
      </DialogActions>
    </Dialog>
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
    setName('');
    setApiKey('');
  }, [open, accountTypes]);

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
      await onSaved();
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
      await probeIntegrationAccountOAuth(display, account.id);
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
          <TextField
            label="Account name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            fullWidth
          />
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
        <Button
          variant="contained"
          disabled={busy || name.trim().length === 0}
          onClick={() => void saveDetails()}
        >
          {account.supports_oauth_sign_in ? 'Save' : 'Save'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
