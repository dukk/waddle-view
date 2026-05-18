import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
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
  Paper,
  Stack,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TextField,
  Typography,
  MenuItem,
  Select,
  FormControl,
  InputLabel,
} from '@mui/material';
import Form from '@rjsf/mui';
import validator from '@rjsf/validator-ajv8';
import type { RJSFSchema } from '@rjsf/utils';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import {
  listIntegrations,
  type IntegrationRow,
  type IntegrationsListParams,
  type IntegrationsSortField,
} from '@/api/integrations';
import { fetchIntegrationAccounts } from '@/api/integrationAccounts';
import { listOAuthProviders, type OAuthProviderStatus } from '@/api/oauthProviders';
import { CatalogPageToolbar } from '@/components/CatalogPageToolbar';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { IntegrationBrandIcon } from '@/components/IntegrationBrandIcon';
import { completeDialogSave } from '@/util/dialogSave';
import { parseJsonObject } from '@/util/json';
import { prepareRjsfSchema } from '@/util/rjsfSchema';
import { fetchIntegrationAccountsDetail } from '@/api/integrationAccounts';
import { AccountsSetupNotice } from '@/components/AccountsSetupNotice';
import { IntegrationAccountChips } from '@/components/IntegrationAccountChips';
import {
  OutlookCalendarConfigSection,
  type ContentCategoryOption,
} from '@/components/OutlookCalendarConfigSection';
import {
  buildOutlookCalendarConfigJson,
  parseOutlookCalendarConfig,
  type OutlookCalendarConfigState,
} from '@/util/outlookCalendarConfig';
import type { IntegrationAccountRow } from '@/util/integrationAccounts';
import {
  integrationAccountsSatisfiedForEnable,
  type IntegrationAccountsDetail,
} from '@/util/integrationAccountStatus';
import { integrationDisplayName } from '@/util/integrationDisplayName';
import { integrationConfigBaseUrl } from '@/util/integrationConfig';

const ROWS_PER_PAGE_OPTIONS = [12, 25, 50] as const;
const DEFAULT_ROWS_PER_PAGE = 12;

type SetupFilter = 'all' | 'ready' | 'needs_secrets' | 'needs_accounts';

function mergeFamilyFacets(
  a?: Record<string, number>,
  b?: Record<string, number>,
): Map<string, number> {
  const m = new Map<string, number>();
  for (const [k, v] of Object.entries(a ?? {})) {
    m.set(k, (m.get(k) ?? 0) + v);
  }
  for (const [k, v] of Object.entries(b ?? {})) {
    m.set(k, (m.get(k) ?? 0) + v);
  }
  return m;
}

function listParamsBase(
  enabled: boolean,
  offset: number,
  rowsPerPage: number,
  sortField: IntegrationsSortField,
  sortOrder: 'asc' | 'desc',
  filterFamily: string | null,
  searchQ: string,
  setupFilter: SetupFilter,
): IntegrationsListParams {
  const params: IntegrationsListParams = {
    enabled,
    limit: rowsPerPage,
    offset,
    sort: sortField,
    order: sortOrder,
    facets: 'family',
  };
  if (filterFamily) params.family = filterFamily;
  const q = searchQ.trim();
  if (q) params.q = q;
  if (setupFilter === 'ready') {
    params.secrets_configured = true;
    params.accounts_configured = true;
  } else if (setupFilter === 'needs_secrets') {
    params.secrets_configured = false;
  } else if (setupFilter === 'needs_accounts') {
    params.accounts_configured = false;
  }
  return params;
}

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
  const { loading: enabledLoading, wrapRefresh: wrapEnabledRefresh } = useDisplayRefresh();
  const { loading: availableLoading, wrapRefresh: wrapAvailableRefresh } = useDisplayRefresh();
  const { wrapRefresh: wrapAuxRefresh } = useDisplayRefresh();
  const { layout, setLayout } = useListLayoutPreference('integrations');
  const [enabledRows, setEnabledRows] = useState<IntegrationRow[]>([]);
  const [availableRows, setAvailableRows] = useState<IntegrationRow[]>([]);
  const [enabledTotal, setEnabledTotal] = useState(0);
  const [availableTotal, setAvailableTotal] = useState(0);
  const [enabledPage, setEnabledPage] = useState(0);
  const [availablePage, setAvailablePage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(DEFAULT_ROWS_PER_PAGE);
  const [familyFacetCounts, setFamilyFacetCounts] = useState<Map<string, number>>(new Map());
  const [accounts, setAccounts] = useState<IntegrationAccountRow[]>([]);
  const [oauthProviders, setOauthProviders] = useState<OAuthProviderStatus[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [edit, setEdit] = useState<IntegrationRow | null>(null);
  const [dialogIntent, setDialogIntent] = useState<'edit' | 'enable'>('edit');
  const [filterFamily, setFilterFamily] = useState<string | null>(null);
  const [setupFilter, setSetupFilter] = useState<SetupFilter>('all');
  const [searchDraft, setSearchDraft] = useState('');
  const [searchQ, setSearchQ] = useState('');
  const [sortField, setSortField] = useState<IntegrationsSortField>('id');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');

  const enabledFetchAbortRef = useRef<AbortController | null>(null);
  const enabledLoadGenerationRef = useRef(0);
  const availableFetchAbortRef = useRef<AbortController | null>(null);
  const availableLoadGenerationRef = useRef(0);
  const enabledFacetsRef = useRef<Record<string, number> | undefined>(undefined);
  const availableFacetsRef = useRef<Record<string, number> | undefined>(undefined);

  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => setSearchQ(searchDraft), 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [searchDraft]);

  useEffect(() => {
    setEnabledPage(0);
    setAvailablePage(0);
  }, [filterFamily, setupFilter, searchQ, sortField, sortOrder, rowsPerPage]);

  const familiesInUse = useMemo(
    () => [...familyFacetCounts.keys()].sort(compareFamilies),
    [familyFacetCounts],
  );

  useEffect(() => {
    if (filterFamily != null && !familiesInUse.includes(filterFamily)) {
      setFilterFamily(null);
    }
  }, [filterFamily, familiesInUse]);

  const catalogTotal = useMemo(() => {
    let sum = 0;
    for (const n of familyFacetCounts.values()) {
      sum += n;
    }
    return sum;
  }, [familyFacetCounts]);

  const enabledOffset = enabledPage * rowsPerPage;
  const availableOffset = availablePage * rowsPerPage;

  const loadEnabled = useCallback(async () => {
    if (!active) return;
    enabledFetchAbortRef.current?.abort();
    const controller = new AbortController();
    enabledFetchAbortRef.current = controller;
    const myGen = ++enabledLoadGenerationRef.current;
    await wrapEnabledRefresh(async () => {
      try {
        const enabledParams = listParamsBase(
          true,
          enabledOffset,
          rowsPerPage,
          sortField,
          sortOrder,
          filterFamily,
          searchQ,
          setupFilter,
        );
        const enabledRes = await listIntegrations(active, enabledParams, {
          signal: controller.signal,
        });
        if (myGen !== enabledLoadGenerationRef.current || controller.signal.aborted) return;
        setEnabledRows(enabledRes.items ?? []);
        setEnabledTotal(typeof enabledRes.total === 'number' ? enabledRes.total : 0);
        enabledFacetsRef.current = enabledRes.facets?.family;
        setFamilyFacetCounts(
          mergeFamilyFacets(enabledFacetsRef.current, availableFacetsRef.current),
        );
        setError(null);
      } catch (e) {
        if (controller.signal.aborted || myGen !== enabledLoadGenerationRef.current) return;
        setError(errMsg(e));
        setEnabledRows([]);
        setEnabledTotal(0);
        enabledFacetsRef.current = undefined;
        setFamilyFacetCounts(
          mergeFamilyFacets(enabledFacetsRef.current, availableFacetsRef.current),
        );
      }
    });
  }, [
    active,
    enabledOffset,
    filterFamily,
    rowsPerPage,
    searchQ,
    setupFilter,
    sortField,
    sortOrder,
    wrapEnabledRefresh,
  ]);

  const loadAvailable = useCallback(async () => {
    if (!active) return;
    availableFetchAbortRef.current?.abort();
    const controller = new AbortController();
    availableFetchAbortRef.current = controller;
    const myGen = ++availableLoadGenerationRef.current;
    await wrapAvailableRefresh(async () => {
      try {
        const availableParams = listParamsBase(
          false,
          availableOffset,
          rowsPerPage,
          sortField,
          sortOrder,
          filterFamily,
          searchQ,
          setupFilter,
        );
        const availableRes = await listIntegrations(active, availableParams, {
          signal: controller.signal,
        });
        if (myGen !== availableLoadGenerationRef.current || controller.signal.aborted) return;
        setAvailableRows(availableRes.items ?? []);
        setAvailableTotal(typeof availableRes.total === 'number' ? availableRes.total : 0);
        availableFacetsRef.current = availableRes.facets?.family;
        setFamilyFacetCounts(
          mergeFamilyFacets(enabledFacetsRef.current, availableFacetsRef.current),
        );
        setError(null);
      } catch (e) {
        if (controller.signal.aborted || myGen !== availableLoadGenerationRef.current) return;
        setError(errMsg(e));
        setAvailableRows([]);
        setAvailableTotal(0);
        availableFacetsRef.current = undefined;
        setFamilyFacetCounts(
          mergeFamilyFacets(enabledFacetsRef.current, availableFacetsRef.current),
        );
      }
    });
  }, [
    active,
    availableOffset,
    filterFamily,
    rowsPerPage,
    searchQ,
    setupFilter,
    sortField,
    sortOrder,
    wrapAvailableRefresh,
  ]);

  const loadAux = useCallback(async () => {
    if (!active) return;
    await wrapAuxRefresh(async () => {
      try {
        const [accountsRes, providers] = await Promise.all([
          fetchIntegrationAccounts(active),
          listOAuthProviders(active),
        ]);
        setAccounts(accountsRes.items ?? []);
        setOauthProviders(providers);
      } catch {
        /* optional metadata for cards/dialog */
      }
    });
  }, [active, wrapAuxRefresh]);

  const reloadAll = useCallback(async () => {
    await Promise.all([loadEnabled(), loadAvailable(), loadAux()]);
  }, [loadEnabled, loadAvailable, loadAux]);

  useEffect(() => {
    void loadEnabled();
    return () => {
      enabledFetchAbortRef.current?.abort();
      enabledLoadGenerationRef.current += 1;
    };
  }, [loadEnabled]);

  useEffect(() => {
    void loadAvailable();
    return () => {
      availableFetchAbortRef.current?.abort();
      availableLoadGenerationRef.current += 1;
    };
  }, [loadAvailable]);

  useEffect(() => {
    void loadAux();
  }, [loadAux]);

  useLayoutEffect(() => {
    setEnabledRows([]);
  }, [filterFamily, setupFilter, searchQ, sortField, sortOrder, rowsPerPage]);

  useLayoutEffect(() => {
    setAvailableRows([]);
  }, [filterFamily, setupFilter, searchQ, sortField, sortOrder, rowsPerPage]);

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={3}>
      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          External data sources
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Connect external data sources—calendars, news, weather, stocks, and more—that collectors
          poll into the display database. Enable providers and complete each integration&apos;s
          configuration.
        </Typography>
      </Box>
      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <AccountsSetupNotice />

      <CatalogPageToolbar layout={layout} onLayoutChange={setLayout} />

      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'flex-end' }}>
        <TextField
          label="Search"
          size="small"
          value={searchDraft}
          onChange={(e) => setSearchDraft(e.target.value)}
          placeholder="Id or integration type"
          sx={{ minWidth: 220, flex: 1 }}
        />
        <FormControl size="small" sx={{ minWidth: 160 }}>
          <InputLabel id="integrations-sort-field">Sort by</InputLabel>
          <Select
            labelId="integrations-sort-field"
            label="Sort by"
            value={sortField}
            onChange={(e) => setSortField(e.target.value as IntegrationsSortField)}
          >
            <MenuItem value="id">Id</MenuItem>
            <MenuItem value="integration_type">Type</MenuItem>
            <MenuItem value="poll_seconds">Poll interval</MenuItem>
            <MenuItem value="enabled">Enabled</MenuItem>
          </Select>
        </FormControl>
        <FormControl size="small" sx={{ minWidth: 120 }}>
          <InputLabel id="integrations-sort-order">Order</InputLabel>
          <Select
            labelId="integrations-sort-order"
            label="Order"
            value={sortOrder}
            onChange={(e) => setSortOrder(e.target.value as 'asc' | 'desc')}
          >
            <MenuItem value="asc">Ascending</MenuItem>
            <MenuItem value="desc">Descending</MenuItem>
          </Select>
        </FormControl>
      </Stack>

      <Stack spacing={1}>
        <Typography variant="subtitle2" color="text.secondary">
          Setup status
        </Typography>
        <Stack direction="row" flexWrap="wrap" useFlexGap spacing={1}>
          {(
            [
              ['all', 'All'],
              ['ready', 'Ready'],
              ['needs_secrets', 'Needs secrets'],
              ['needs_accounts', 'Needs accounts'],
            ] as const
          ).map(([id, label]) => (
            <Chip
              key={id}
              label={label}
              onClick={() => setSetupFilter(id)}
              color={setupFilter === id ? 'primary' : 'default'}
              variant={setupFilter === id ? 'filled' : 'outlined'}
              clickable
            />
          ))}
        </Stack>
      </Stack>

      <Stack spacing={1}>
        <Typography variant="subtitle2" color="text.secondary">
          Filter by data type
        </Typography>
        <Stack direction="row" flexWrap="wrap" useFlexGap spacing={1}>
          <Chip
            label={`All (${catalogTotal})`}
            onClick={() => setFilterFamily(null)}
            color={filterFamily === null ? 'primary' : 'default'}
            variant={filterFamily === null ? 'filled' : 'outlined'}
            clickable
          />
          {familiesInUse.map((family) => {
            const n = familyFacetCounts.get(family) ?? 0;
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

      {!enabledLoading &&
      !availableLoading &&
      enabledTotal === 0 &&
      availableTotal === 0 ? (
        <Typography variant="body2" color="text.secondary">
          No integrations match the current filters.
        </Typography>
      ) : null}

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Enabled
        </Typography>
        <DisplayRefreshIndicator loading={enabledLoading} />
        {enabledRows.length === 0 && !enabledLoading ? (
          <Typography variant="body2" color="text.secondary">
            {filterFamily != null || searchQ || setupFilter !== 'all'
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
                onAccountsChanged={reloadAll}
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
        <TablePagination
          component="div"
          rowsPerPageOptions={[...ROWS_PER_PAGE_OPTIONS]}
          rowsPerPage={rowsPerPage}
          count={enabledTotal}
          page={enabledPage}
          onPageChange={(_, p) => setEnabledPage(p)}
          onRowsPerPageChange={(e) => {
            setRowsPerPage(parseInt(e.target.value, 10));
            setEnabledPage(0);
            setAvailablePage(0);
          }}
        />
      </Stack>

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Available to enable
        </Typography>
        <DisplayRefreshIndicator loading={availableLoading} />
        {availableRows.length === 0 && !availableLoading ? (
          <Typography variant="body2" color="text.secondary">
            {filterFamily != null || searchQ || setupFilter !== 'all'
              ? 'No disabled integrations match this filter.'
              : 'All integrations are enabled.'}
          </Typography>
        ) : layout === 'card' ? (
          <Box sx={catalogCardGridSx}>
            {availableRows.map((r) => (
              <IntegrationCard
                key={r.id}
                row={r}
                actionLabel="Enable"
                onAccountsChanged={reloadAll}
                onAction={() => {
                  setDialogIntent('enable');
                  setEdit(r);
                }}
              />
            ))}
          </Box>
        ) : (
          <IntegrationTable
            rows={availableRows}
            actionLabel="Enable"
            onAction={(r) => {
              setDialogIntent('enable');
              setEdit(r);
            }}
          />
        )}
        <TablePagination
          component="div"
          rowsPerPageOptions={[...ROWS_PER_PAGE_OPTIONS]}
          rowsPerPage={rowsPerPage}
          count={availableTotal}
          page={availablePage}
          onPageChange={(_, p) => setAvailablePage(p)}
          onRowsPerPageChange={(e) => {
            setRowsPerPage(parseInt(e.target.value, 10));
            setEnabledPage(0);
            setAvailablePage(0);
          }}
        />
      </Stack>

      {edit && (
        <EditIntegrationDialog
          row={edit}
          intent={dialogIntent}
          oauthProviders={oauthProviders}
          microsoftAccounts={accounts.filter((a) => a.account_type === 'microsoft_graph')}
          onClose={() => setEdit(null)}
          onSaved={async () => {
            setEdit(null);
            await reloadAll();
          }}
        />
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
              baseUrl={integrationConfigBaseUrl(row.config_json)}
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
          {integrationConfigBaseUrl(row.config_json) ? (
            <Typography variant="caption" color="text.secondary" sx={{ wordBreak: 'break-all' }}>
              {integrationConfigBaseUrl(row.config_json)}
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

const kOutlookCalendarIntegrationType = 'calendar_outlook';

function EditIntegrationDialog({
  row,
  intent,
  oauthProviders,
  microsoftAccounts,
  onClose,
  onSaved,
}: {
  row: IntegrationRow;
  intent: 'edit' | 'enable';
  oauthProviders: OAuthProviderStatus[];
  microsoftAccounts: IntegrationAccountRow[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const isOutlookCalendar = row.integration_type === kOutlookCalendarIntegrationType;
  const schema = useMemo(() => integrationConfigSchema(row), [row]);
  const [enabled, setEnabled] = useState(() => (intent === 'enable' ? true : row.enabled));
  const [poll, setPoll] = useState(row.poll_seconds);
  const [formData, setFormData] = useState<Record<string, unknown>>(() =>
    parseJsonObject(row.config_json),
  );
  const [outlookConfig, setOutlookConfig] = useState<OutlookCalendarConfigState>(() =>
    parseOutlookCalendarConfig(parseJsonObject(row.config_json)),
  );
  const [curatorCategories, setCuratorCategories] = useState<ContentCategoryOption[]>([]);
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
    if (!active || !isOutlookCalendar) return;
    let cancelled = false;
    void (async () => {
      try {
        const res = await apiJson<{ items: ContentCategoryOption[] }>(
          active,
          '/v1/curator/categories',
        );
        if (!cancelled) {
          setCuratorCategories(res.items ?? []);
        }
      } catch {
        if (!cancelled) {
          setCuratorCategories([]);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [active, isOutlookCalendar]);

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

  const outlookConfigReady = useMemo(() => {
    if (!isOutlookCalendar) return true;
    if (!outlookConfig.graphAccountKey) return false;
    const account = microsoftAccounts.find((a) => a.id === outlookConfig.graphAccountKey);
    if (!account?.configured) return false;
    return outlookConfig.calendars.some((c) => c.selected);
  }, [isOutlookCalendar, outlookConfig, microsoftAccounts]);

  const accountsReady = useMemo(() => {
    if (isOutlookCalendar) {
      return outlookConfigReady;
    }
    return integrationAccountsSatisfiedForEnable(accountDetail);
  }, [isOutlookCalendar, accountDetail, outlookConfigReady]);

  const configForSave = useMemo(() => {
    if (isOutlookCalendar) {
      return buildOutlookCalendarConfigJson(outlookConfig);
    }
    return formData;
  }, [isOutlookCalendar, outlookConfig, formData]);

  const displayName = useMemo(
    () => integrationDisplayName(row.integration_type),
    [row.integration_type],
  );

  const save = async () => {
    if (!active) return;
    setErr(null);
    if (enabled) {
      const { errors } = validator.validateFormData(configForSave, schema);
      if (errors.length > 0) {
        setErr(errors.map((e) => e.stack ?? e.message ?? 'Invalid field').join('\n'));
        return;
      }
      if (isOutlookCalendar && !outlookConfigReady) {
        setErr('Choose a signed-in Microsoft account and at least one calendar to sync.');
        return;
      }
    }
    if (poll <= 0) {
      setErr('Poll seconds must be greater than zero.');
      return;
    }
    if (enabled && !oauthClientIdsReady) {
      setErr(
        'Configure required OAuth client IDs under Display settings → Accounts before enabling.',
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
          config_json: configForSave,
        }),
      });
      await reloadAccounts();
      await completeDialogSave(onSaved, onClose);
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
            baseUrl={integrationConfigBaseUrl(row.config_json)}
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
              Set OAuth client IDs under <strong>Display settings → Accounts</strong> before
              enabling.
            </Alert>
          ) : null}
          {accountsLoading ? (
            <Typography variant="body2" color="text.secondary">
              Loading accounts…
            </Typography>
          ) : active && accountDetail && !isOutlookCalendar ? (
            <IntegrationAccountChips
              display={active}
              detail={accountDetail}
              onChanged={reloadAccounts}
            />
          ) : null}
          {!accountsReady && accountDetail && !isOutlookCalendar ? (
            <Alert severity="info">
              Add accounts under <strong>Display settings → Accounts</strong>, or link account keys in
              Configuration below, then complete sign-in or API keys.
            </Alert>
          ) : null}
          {!outlookConfigReady && isOutlookCalendar ? (
            <Alert severity="info">
              Choose a Microsoft account and at least one calendar below. Add accounts under{' '}
              <strong>Display settings → Accounts</strong> if none appear.
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
          {isOutlookCalendar && integrationConfigBaseUrl(row.config_json) ? (
            <Typography variant="caption" color="text.secondary" display="block">
              Microsoft Graph endpoint: {integrationConfigBaseUrl(row.config_json)}
            </Typography>
          ) : null}
          {isOutlookCalendar && active ? (
            <OutlookCalendarConfigSection
              display={active}
              value={outlookConfig}
              onChange={setOutlookConfig}
              microsoftAccounts={microsoftAccounts}
              categories={curatorCategories}
            />
          ) : (
            <>
              <Typography variant="subtitle2">Configuration</Typography>
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
            </>
          )}
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
