import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import type { IntegrationSecretSlot } from '@/util/integrationSecrets';
import { integrationSecretsSatisfiedForEnable } from '@/util/integrationSecrets';
import { Link as RouterLink } from 'react-router-dom';
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
  Link as MuiLink,
} from '@mui/material';
import validator from '@rjsf/validator-ajv8';
import type { RJSFSchema } from '@rjsf/utils';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import {
  listIntegrations,
  type IntegrationRow,
  type IntegrationsListParams,
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
import { SchemaConfigForm } from '@/components/config/SchemaConfigForm';
import {
  DISPLAY_SETTINGS_ACCOUNTS_LABEL,
  DISPLAY_SETTINGS_TAB_ACCOUNTS,
  displaySettingsPath,
} from '@/constants/displaySettingsTabs';
import {
  mergeIntegrationConfigForSave,
  prepareIntegrationOperatorSchema,
} from '@/util/integrationOperatorSchema';
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
import { formatPollInterval } from '@/util/pollIntervalFormat';
import { useConfigSchemas } from '@/hooks/useConfigSchemas';
import {
  schemaForIntegrationType,
  type ConfigSchemasBundle,
} from '@/storage/configSchemaCache';

const ROWS_PER_PAGE_OPTIONS = [15, 25, 50] as const;
const DEFAULT_ROWS_PER_PAGE = 15;
const INTEGRATIONS_PER_PAGE_LABEL = 'Integrations per page:';

type IntegrationListSection = 'enabled' | 'available' | 'missing';

function listParamsForSection(
  section: IntegrationListSection,
  offset: number,
  rowsPerPage: number,
): IntegrationsListParams {
  const base: IntegrationsListParams = {
    limit: rowsPerPage,
    offset,
  };
  if (section === 'missing') {
    return { ...base, accounts_configured: false };
  }
  return {
    ...base,
    enabled: section === 'enabled',
    accounts_configured: true,
  };
}

function actionLabelForIntegrationRow(row: IntegrationRow): string {
  return row.enabled ? 'Edit' : 'Enable';
}

/** Missing-accounts section: edit enabled integrations only (no enable until accounts are ready). */
function missingAccountsActionLabel(row: IntegrationRow): string | null {
  return row.enabled ? 'Edit' : null;
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

function integrationValidationSchema(
  schemas: ConfigSchemasBundle | null,
  row: IntegrationRow,
): RJSFSchema {
  return prepareRjsfSchema(schemaForIntegrationType(schemas, row.integration_type));
}

function integrationOperatorSchema(
  schemas: ConfigSchemasBundle | null,
  row: IntegrationRow,
): RJSFSchema {
  return prepareIntegrationOperatorSchema(
    schemaForIntegrationType(schemas, row.integration_type),
  );
}

function configJsonSatisfiesSchema(
  schemas: ConfigSchemasBundle | null,
  row: IntegrationRow,
): boolean {
  const schema = integrationValidationSchema(schemas, row);
  const formData = parseJsonObject(row.config_json);
  const { errors } = validator.validateFormData(formData, schema);
  return errors.length === 0;
}

function IntegrationTable({
  schemas,
  rows,
  actionLabel,
  actionLabelForRow,
  onAction,
}: {
  schemas: ConfigSchemasBundle | null;
  rows: IntegrationRow[];
  actionLabel?: string;
  actionLabelForRow?: (row: IntegrationRow) => string | null;
  onAction: (row: IntegrationRow) => void;
}) {
  const labelFor = (row: IntegrationRow): string | null =>
    actionLabelForRow?.(row) ?? actionLabel ?? 'Open';
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
            const configOk = configJsonSatisfiesSchema(schemas, row);
            const rowActionLabel = labelFor(row);
            const showConfigHint = rowActionLabel === 'Enable' && !configOk;
            return (
              <TableRow key={row.id} hover>
                <TableCell sx={{ fontWeight: 600 }}>{displayName}</TableCell>
                <TableCell>{formatPollInterval(row.poll_seconds)}</TableCell>
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
                  {rowActionLabel ? (
                    <Button size="small" variant="outlined" onClick={() => onAction(row)}>
                      {rowActionLabel}
                    </Button>
                  ) : null}
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
  const { schemas, error: schemasError } = useConfigSchemas(active);
  const { loading: enabledLoading, wrapRefresh: wrapEnabledRefresh } = useDisplayRefresh();
  const { loading: availableLoading, wrapRefresh: wrapAvailableRefresh } = useDisplayRefresh();
  const { loading: missingLoading, wrapRefresh: wrapMissingRefresh } = useDisplayRefresh();
  const { wrapRefresh: wrapAuxRefresh } = useDisplayRefresh();
  const { layout, setLayout } = useListLayoutPreference('integrations');
  const [enabledRows, setEnabledRows] = useState<IntegrationRow[]>([]);
  const [availableRows, setAvailableRows] = useState<IntegrationRow[]>([]);
  const [enabledTotal, setEnabledTotal] = useState(0);
  const [availableTotal, setAvailableTotal] = useState(0);
  const [enabledPage, setEnabledPage] = useState(0);
  const [availablePage, setAvailablePage] = useState(0);
  const [missingRows, setMissingRows] = useState<IntegrationRow[]>([]);
  const [missingTotal, setMissingTotal] = useState(0);
  const [missingPage, setMissingPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(DEFAULT_ROWS_PER_PAGE);
  const [accounts, setAccounts] = useState<IntegrationAccountRow[]>([]);
  const [oauthProviders, setOauthProviders] = useState<OAuthProviderStatus[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [edit, setEdit] = useState<IntegrationRow | null>(null);
  const [dialogIntent, setDialogIntent] = useState<'edit' | 'enable'>('edit');
  const enabledFetchAbortRef = useRef<AbortController | null>(null);
  const enabledLoadGenerationRef = useRef(0);
  const availableFetchAbortRef = useRef<AbortController | null>(null);
  const availableLoadGenerationRef = useRef(0);
  const missingFetchAbortRef = useRef<AbortController | null>(null);
  const missingLoadGenerationRef = useRef(0);

  const resetAllPages = useCallback(() => {
    setEnabledPage(0);
    setAvailablePage(0);
    setMissingPage(0);
  }, []);

  useEffect(() => {
    resetAllPages();
  }, [rowsPerPage, resetAllPages]);

  const enabledOffset = enabledPage * rowsPerPage;
  const availableOffset = availablePage * rowsPerPage;
  const missingOffset = missingPage * rowsPerPage;

  const loadEnabled = useCallback(async () => {
    if (!active) return;
    enabledFetchAbortRef.current?.abort();
    const controller = new AbortController();
    enabledFetchAbortRef.current = controller;
    const myGen = ++enabledLoadGenerationRef.current;
    await wrapEnabledRefresh(async () => {
      try {
        const enabledParams = listParamsForSection('enabled', enabledOffset, rowsPerPage);
        const enabledRes = await listIntegrations(active, enabledParams, {
          signal: controller.signal,
        });
        if (myGen !== enabledLoadGenerationRef.current || controller.signal.aborted) return;
        setEnabledRows(enabledRes.items ?? []);
        setEnabledTotal(typeof enabledRes.total === 'number' ? enabledRes.total : 0);
        setError(null);
      } catch (e) {
        if (controller.signal.aborted || myGen !== enabledLoadGenerationRef.current) return;
        setError(errMsg(e));
        setEnabledRows([]);
        setEnabledTotal(0);
      }
    });
  }, [active, enabledOffset, rowsPerPage, wrapEnabledRefresh]);

  const loadAvailable = useCallback(async () => {
    if (!active) return;
    availableFetchAbortRef.current?.abort();
    const controller = new AbortController();
    availableFetchAbortRef.current = controller;
    const myGen = ++availableLoadGenerationRef.current;
    await wrapAvailableRefresh(async () => {
      try {
        const availableParams = listParamsForSection('available', availableOffset, rowsPerPage);
        const availableRes = await listIntegrations(active, availableParams, {
          signal: controller.signal,
        });
        if (myGen !== availableLoadGenerationRef.current || controller.signal.aborted) return;
        setAvailableRows(availableRes.items ?? []);
        setAvailableTotal(typeof availableRes.total === 'number' ? availableRes.total : 0);
        setError(null);
      } catch (e) {
        if (controller.signal.aborted || myGen !== availableLoadGenerationRef.current) return;
        setError(errMsg(e));
        setAvailableRows([]);
        setAvailableTotal(0);
      }
    });
  }, [active, availableOffset, rowsPerPage, wrapAvailableRefresh]);

  const loadMissing = useCallback(async () => {
    if (!active) return;
    missingFetchAbortRef.current?.abort();
    const controller = new AbortController();
    missingFetchAbortRef.current = controller;
    const myGen = ++missingLoadGenerationRef.current;
    await wrapMissingRefresh(async () => {
      try {
        const missingParams = listParamsForSection('missing', missingOffset, rowsPerPage);
        const missingRes = await listIntegrations(active, missingParams, {
          signal: controller.signal,
        });
        if (myGen !== missingLoadGenerationRef.current || controller.signal.aborted) return;
        setMissingRows(missingRes.items ?? []);
        setMissingTotal(typeof missingRes.total === 'number' ? missingRes.total : 0);
        setError(null);
      } catch (e) {
        if (controller.signal.aborted || myGen !== missingLoadGenerationRef.current) return;
        setError(errMsg(e));
        setMissingRows([]);
        setMissingTotal(0);
      }
    });
  }, [active, missingOffset, rowsPerPage, wrapMissingRefresh]);

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
    await Promise.all([loadEnabled(), loadAvailable(), loadMissing(), loadAux()]);
  }, [loadEnabled, loadAvailable, loadMissing, loadAux]);

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
    void loadMissing();
    return () => {
      missingFetchAbortRef.current?.abort();
      missingLoadGenerationRef.current += 1;
    };
  }, [loadMissing]);

  useEffect(() => {
    void loadAux();
  }, [loadAux]);

  useLayoutEffect(() => {
    setEnabledRows([]);
  }, [rowsPerPage]);

  useLayoutEffect(() => {
    setAvailableRows([]);
  }, [rowsPerPage]);

  useLayoutEffect(() => {
    setMissingRows([]);
  }, [rowsPerPage]);

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
      {(error || schemasError) && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error ?? schemasError}
        </Alert>
      )}

      <AccountsSetupNotice />

      <CatalogPageToolbar layout={layout} onLayoutChange={setLayout} />

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Enabled
        </Typography>
        <DisplayRefreshIndicator loading={enabledLoading} />
        {enabledRows.length === 0 && !enabledLoading ? (
          <Typography variant="body2" color="text.secondary">
            No integrations are enabled.
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
            schemas={schemas}
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
          labelRowsPerPage={INTEGRATIONS_PER_PAGE_LABEL}
          rowsPerPageOptions={[...ROWS_PER_PAGE_OPTIONS]}
          rowsPerPage={rowsPerPage}
          count={enabledTotal}
          page={enabledPage}
          onPageChange={(_, p) => setEnabledPage(p)}
          onRowsPerPageChange={(e) => {
            setRowsPerPage(parseInt(e.target.value, 10));
            resetAllPages();
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
            All integrations are enabled.
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
            schemas={schemas}
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
          labelRowsPerPage={INTEGRATIONS_PER_PAGE_LABEL}
          rowsPerPageOptions={[...ROWS_PER_PAGE_OPTIONS]}
          rowsPerPage={rowsPerPage}
          count={availableTotal}
          page={availablePage}
          onPageChange={(_, p) => setAvailablePage(p)}
          onRowsPerPageChange={(e) => {
            setRowsPerPage(parseInt(e.target.value, 10));
            resetAllPages();
          }}
        />
      </Stack>

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Missing required accounts
        </Typography>
        <Typography variant="body2" color="text.secondary">
          These integrations need shared accounts before they can run or be enabled. Configure them
          under{' '}
          <MuiLink
            component={RouterLink}
            to={displaySettingsPath(DISPLAY_SETTINGS_TAB_ACCOUNTS)}
          >
            {DISPLAY_SETTINGS_ACCOUNTS_LABEL}
          </MuiLink>
          .
        </Typography>
        <DisplayRefreshIndicator loading={missingLoading} />
        {missingRows.length === 0 && !missingLoading ? (
          <Typography variant="body2" color="text.secondary">
            All integrations that require accounts are configured.
          </Typography>
        ) : layout === 'card' ? (
          <Box sx={catalogCardGridSx}>
            {missingRows.map((r) => (
              <IntegrationCard
                key={r.id}
                row={r}
                actionLabel={missingAccountsActionLabel(r)}
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
            schemas={schemas}
            rows={missingRows}
            actionLabelForRow={missingAccountsActionLabel}
            onAction={(r) => {
              setDialogIntent('edit');
              setEdit(r);
            }}
          />
        )}
        <TablePagination
          component="div"
          labelRowsPerPage={INTEGRATIONS_PER_PAGE_LABEL}
          rowsPerPageOptions={[...ROWS_PER_PAGE_OPTIONS]}
          rowsPerPage={rowsPerPage}
          count={missingTotal}
          page={missingPage}
          onPageChange={(_, p) => setMissingPage(p)}
          onRowsPerPageChange={(e) => {
            setRowsPerPage(parseInt(e.target.value, 10));
            resetAllPages();
          }}
        />
      </Stack>

      {edit && schemas && (
        <EditIntegrationDialog
          schemas={schemas}
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
  actionLabel?: string | null;
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
            Poll every {formatPollInterval(row.poll_seconds)}
          </Typography>
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
      {actionLabel ? (
        <CardActions sx={{ justifyContent: 'flex-end', px: 2, pb: 2 }}>
          <Button size="small" variant="outlined" onClick={onAction}>
            {actionLabel}
          </Button>
        </CardActions>
      ) : null}
    </Card>
  );
}

const kOutlookCalendarIntegrationType = 'calendar_outlook';

function EditIntegrationDialog({
  schemas,
  row,
  intent,
  oauthProviders,
  microsoftAccounts,
  onClose,
  onSaved,
}: {
  schemas: ConfigSchemasBundle;
  row: IntegrationRow;
  intent: 'edit' | 'enable';
  oauthProviders: OAuthProviderStatus[];
  microsoftAccounts: IntegrationAccountRow[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const isOutlookCalendar = row.integration_type === kOutlookCalendarIntegrationType;
  const operatorSchema = useMemo(
    () => integrationOperatorSchema(schemas, row),
    [schemas, row],
  );
  const validationSchema = useMemo(
    () => integrationValidationSchema(schemas, row),
    [schemas, row],
  );
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
    const built = isOutlookCalendar
      ? buildOutlookCalendarConfigJson(outlookConfig)
      : formData;
    return mergeIntegrationConfigForSave(built, row.config_json);
  }, [isOutlookCalendar, outlookConfig, formData, row.config_json]);

  const displayName = useMemo(
    () => integrationDisplayName(row.integration_type),
    [row.integration_type],
  );

  const save = async () => {
    if (!active) return;
    setErr(null);
    if (enabled) {
      const { errors } = validator.validateFormData(configForSave, validationSchema);
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
        `Configure required OAuth client IDs under ${DISPLAY_SETTINGS_ACCOUNTS_LABEL} before enabling.`,
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
              Set OAuth client IDs under <strong>{DISPLAY_SETTINGS_ACCOUNTS_LABEL}</strong> before
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
              Add accounts under <strong>{DISPLAY_SETTINGS_ACCOUNTS_LABEL}</strong>, or link account
              keys in <strong>Configuration</strong> below, then complete sign-in or enter API keys.
            </Alert>
          ) : null}
          {!outlookConfigReady && isOutlookCalendar ? (
            <Alert severity="info">
              Choose a Microsoft account and at least one calendar below. Add accounts under{' '}
              <strong>{DISPLAY_SETTINGS_ACCOUNTS_LABEL}</strong> if none are listed.
            </Alert>
          ) : null}
          {secretsLoading ? (
            <Typography variant="body2" color="text.secondary">
              Loading secrets…
            </Typography>
          ) : secretSlots.length > 0 ? (
            <Stack spacing={1.5}>
              <Typography variant="subtitle2">Secrets</Typography>
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
            label="Poll interval (seconds)"
            type="number"
            value={poll}
            onChange={(e) => setPoll(Number(e.target.value) || 0)}
            fullWidth
          />
          {isOutlookCalendar && active ? (
            <OutlookCalendarConfigSection
              display={active}
              value={outlookConfig}
              onChange={setOutlookConfig}
              microsoftAccounts={microsoftAccounts}
              categories={curatorCategories}
            />
          ) : (
            active ? (
              <Stack spacing={1}>
                <Typography variant="subtitle2">Configuration</Typography>
                <SchemaConfigForm
                  display={active}
                  schema={operatorSchema}
                  formData={formData}
                  onChange={setFormData}
                />
              </Stack>
            ) : null
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
