import { useCallback, useEffect, useMemo, useState } from 'react';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
  Autocomplete,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Checkbox,
  Stack,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tabs,
  TextField,
  Typography,
} from '@mui/material';
import {
  issueApiClient,
  listApiClients,
  revokeApiClient,
  type ApiClientListItem,
} from '@/api/apiClients';
import { resolveClientIdentifier } from '@/util/clientIdentifier';
import { suggestAdoptionIdentifier } from '@/util/adoptionDisplayIdentity';
import type { SavedDisplay } from '@/storage/displays';
import { useAuth } from '@/context/AuthContext';
import { useControllerAuth } from '@/context/ControllerAuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { CuratorCategoriesSection } from '@/components/curator/CuratorCategoriesSection';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import { DisplayThemePaletteSwatches } from '@/components/DisplayThemePaletteSwatches';
import { TickerMarqueeSamplePreview } from '@/components/TickerMarqueeSamplePreview';
import { RejectTermsSection } from '@/components/curator/RejectTermsSection';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import {
  displayTimezoneSelectOptions,
  filterDisplayTimezoneOptions,
  type DisplayTimezoneOption,
} from '@/constants/displayTimezoneOptions';
import { formatProgramDurationWithSeconds } from '@/util/programDurationFormat';
import {
  ADOPTION_ROLES,
  CURATOR_HISTORY_DEPTH,
  CURATOR_PROGRAM_DURATION,
  CURATOR_TICKER_PIXELS_PER_SECOND,
  curatorThemeById,
  curatorThemeIds,
  curatorTextScaleIds,
  parseAdoptionAllowedRoles,
  type CuratorDisplaySettings,
} from '@/constants/curatorDisplaySettings';
type DisplaySettingsTabId = 'general' | 'categories' | 'reject-terms' | 'adoption';

function clampNumber(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function parseTickerPixelsPerSecond(raw: string): number {
  const parsed = Number.parseInt(raw.trim(), 10);
  if (!Number.isFinite(parsed)) {
    return CURATOR_TICKER_PIXELS_PER_SECOND.default;
  }
  return clampNumber(
    parsed,
    CURATOR_TICKER_PIXELS_PER_SECOND.min,
    CURATOR_TICKER_PIXELS_PER_SECOND.max,
  );
}

export function DisplaySettingsPage() {
  const { active } = useDisplay();
  const { hasPermission, session } = useAuth();
  const [tab, setTab] = useState<DisplaySettingsTabId>('general');
  const [kvWriteTick, setKvWriteTick] = useState(0);
  const canCuratorRead = hasPermission('curator.read');
  const canCuratorWrite = hasPermission('curator.write');
  const canRejectTerms = hasPermission('reject_terms.manage');
  const showDisplaySettings = Boolean(active && canCuratorRead);
  const showAdoptionSettings = Boolean(active && canCuratorWrite);
  const showApiClientManagement = Boolean(active && hasPermission('users.manage'));
  const displayLabel = active?.label ?? 'Display';

  const visibleTabs = useMemo(() => {
    const tabs: { id: DisplaySettingsTabId; label: string }[] = [
      { id: 'general', label: 'General' },
    ];
    if (canCuratorRead) {
      tabs.push({ id: 'categories', label: 'Categories' });
    }
    if (canRejectTerms) {
      tabs.push({ id: 'reject-terms', label: 'Rejected terms' });
    }
    tabs.push({ id: 'adoption', label: 'Adoption' });
    return tabs;
  }, [canCuratorRead, canRejectTerms]);

  useEffect(() => {
    if (!visibleTabs.some((t) => t.id === tab)) {
      setTab(visibleTabs[0]!.id);
    }
  }, [visibleTabs, tab]);

  return (
    <Stack spacing={2}>
      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          Curator & display setup — {displayLabel}
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Theme, program duration, ticker speed, content categories, reject terms, adoption roles,
          and REST API keys for <strong>{displayLabel}</strong>. Most curator values affect the next
          program the display builds.
        </Typography>
      </Box>
      <Paper sx={{ px: 2, pt: 1 }}>
        <Tabs
          value={tab}
          onChange={(_, v) => setTab(v as DisplaySettingsTabId)}
          variant="scrollable"
          scrollButtons="auto"
          sx={{ borderBottom: 1, borderColor: 'divider' }}
        >
          {visibleTabs.map((t) => (
            <Tab key={t.id} label={t.label} value={t.id} />
          ))}
        </Tabs>
      </Paper>

      <Paper sx={{ p: 2 }}>
        {tab === 'general' && (
          <Stack spacing={3}>
            {!active && (
              <Alert severity="info">Select a display in the toolbar to edit display settings.</Alert>
            )}
            {active && !canCuratorRead && (
              <Alert severity="warning">
                Your adopted role does not include <strong>curator.read</strong>, so display tuning
                is not available.
              </Alert>
            )}
            {showDisplaySettings && active && (
              <>
                <CuratorDisplaySettingsSection
                  display={active}
                  canWrite={canCuratorWrite}
                  kvWriteTick={kvWriteTick}
                />
                <Accordion disableGutters elevation={0} sx={{ '&:before': { display: 'none' } }}>
                  <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                    <Typography variant="subtitle2" fontWeight={600}>
                      Advanced: config key–values
                    </Typography>
                  </AccordionSummary>
                  <AccordionDetails sx={{ pt: 0 }}>
                    <AdvancedConfigKeyValuesSection
                      display={active}
                      canWrite={canCuratorWrite}
                      embedded
                      onApplied={() => setKvWriteTick((t) => t + 1)}
                    />
                  </AccordionDetails>
                </Accordion>
              </>
            )}
          </Stack>
        )}

        {tab === 'categories' && (
          <>
            {!active && <NoDisplayPlaceholder />}
            {active && !canCuratorRead && (
              <Alert severity="warning">
                Your adopted role does not include <strong>curator.read</strong>, so categories are
                not available.
              </Alert>
            )}
            {active && canCuratorRead && (
              <CuratorCategoriesSection display={active} canWrite={canCuratorWrite} />
            )}
          </>
        )}

        {tab === 'reject-terms' && (
          <>
            {!active && <NoDisplayPlaceholder />}
            {active && !canRejectTerms && (
              <Alert severity="warning">
                Your adopted role does not include <strong>reject_terms.manage</strong>, so rejected
                terms are not available.
              </Alert>
            )}
            {active && canRejectTerms && <RejectTermsSection display={active} />}
          </>
        )}

        {tab === 'adoption' && (
          <Stack spacing={2}>
            {!active && (
              <Alert severity="info">Select a display in the toolbar to edit adoption settings.</Alert>
            )}
            {active && !showAdoptionSettings && (
              <Alert severity="warning">
                Your adopted role does not include <strong>curator.write</strong>, so adoption
                settings are not available.
              </Alert>
            )}
            {showAdoptionSettings && active && (
              <DisplayAdoptionSettingsSection display={active} />
            )}
            {showApiClientManagement && active && (
              <ApiClientsManagementSection display={active} sessionIdentifier={session?.identifier} />
            )}
            {active && !showAdoptionSettings && !showApiClientManagement && (
              <Alert severity="warning">
                Your adopted role cannot manage adoption settings or API keys on this display.
              </Alert>
            )}
          </Stack>
        )}
      </Paper>
    </Stack>
  );
}

const API_CLIENT_ROLES = [
  { value: 'admin', label: 'Admin' },
  { value: 'operator', label: 'Operator' },
  { value: 'power_viewer', label: 'Power viewer' },
  { value: 'viewer', label: 'Viewer' },
] as const;

function formatIssueDate(ms: number): string {
  if (!Number.isFinite(ms) || ms <= 0) return '—';
  return new Date(ms).toLocaleString();
}

function ApiClientsManagementSection({
  display,
  sessionIdentifier,
}: {
  display: SavedDisplay;
  sessionIdentifier?: string;
}) {
  const { status } = useControllerAuth();
  const clientId = resolveClientIdentifier(status, 'controller');
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [initialized, setInitialized] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [clients, setClients] = useState<ApiClientListItem[]>([]);
  const [issueOpen, setIssueOpen] = useState(false);
  const [issueIdentifier, setIssueIdentifier] = useState(clientId.value);
  const [issueRole, setIssueRole] = useState<string>('operator');
  const [issueBusy, setIssueBusy] = useState(false);
  const [issuedKey, setIssuedKey] = useState<string | null>(null);
  const [revokeBusyId, setRevokeBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    await wrapRefresh(async () => {
      setError(null);
      try {
        setClients(await listApiClients(display));
        setInitialized(true);
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    });
  }, [display, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (!issueOpen || issuedKey) return;
    setIssueIdentifier(
      suggestAdoptionIdentifier(display.baseUrl, issueRole, clientId.value),
    );
  }, [issueOpen, issuedKey, display.baseUrl, issueRole, clientId.value]);

  const openIssue = () => {
    setIssuedKey(null);
    setIssueIdentifier(
      suggestAdoptionIdentifier(display.baseUrl, issueRole, clientId.value),
    );
    setIssueOpen(true);
  };

  const submitIssue = async () => {
    setIssueBusy(true);
    setError(null);
    try {
      const result = await issueApiClient(display, {
        identifier: issueIdentifier.trim(),
        role: issueRole,
      });
      setIssuedKey(result.api_key);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setIssueBusy(false);
    }
  };

  const revoke = async (client: ApiClientListItem) => {
    const revokeMessage =
      sessionIdentifier && client.identifier === sessionIdentifier
        ? `Revoke API key for "${client.identifier}"? This may end your current controller session for this display.`
        : `Revoke API key for "${client.identifier}"?`;
    if (!window.confirm(revokeMessage)) {
      return;
    }
    setRevokeBusyId(client.id);
    setError(null);
    try {
      await revokeApiClient(display, client.id);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setRevokeBusyId(null);
    }
  };

  return (
    <Box>
      <DisplayRefreshIndicator loading={loading} />
      <Typography variant="subtitle1" fontWeight={600} gutterBottom>
        API keys
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Adopted REST clients for this display. Plaintext keys are shown only when issued; stored keys
        are listed masked by fingerprint.
      </Typography>
      {error && (
        <Alert severity="error" sx={{ mb: 1 }}>
          {error}
        </Alert>
      )}
      <Stack direction="row" spacing={1} sx={{ mb: 2 }}>
        <Button variant="contained" size="small" onClick={openIssue}>
          Issue new API key
        </Button>
        <Button variant="outlined" size="small" disabled={loading} onClick={() => void load()}>
          Refresh
        </Button>
      </Stack>
      {loading && !initialized ? (
        <Typography variant="body2" color="text.secondary">
          Loading API keys…
        </Typography>
      ) : clients.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          No API keys on this display yet.
        </Typography>
      ) : (
        <TableContainer>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>API key</TableCell>
                <TableCell>Role</TableCell>
                <TableCell>Client identifier</TableCell>
                <TableCell>Issued</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {clients.map((client) => (
                <TableRow key={client.id}>
                  <TableCell>
                    <Typography variant="body2" fontFamily="monospace">
                      {client.masked_api_key}
                    </Typography>
                  </TableCell>
                  <TableCell>{client.role}</TableCell>
                  <TableCell>{client.identifier}</TableCell>
                  <TableCell>{formatIssueDate(client.created_at_ms)}</TableCell>
                  <TableCell align="right">
                    <Button
                      size="small"
                      color="error"
                      disabled={revokeBusyId === client.id}
                      onClick={() => void revoke(client)}
                    >
                      Revoke
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Dialog open={issueOpen} onClose={() => setIssueOpen(false)} fullWidth maxWidth="sm">
        <DialogTitle>Issue API key</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            {issuedKey ? (
              <Alert severity="warning">
                Copy this API key now — it will not be shown again:
                <Typography component="p" fontFamily="monospace" sx={{ mt: 1, wordBreak: 'break-all' }}>
                  {issuedKey}
                </Typography>
              </Alert>
            ) : (
              <>
                <TextField
                  label="Client identifier"
                  value={issueIdentifier}
                  onChange={(e) => setIssueIdentifier(e.target.value)}
                  fullWidth
                  required
                  disabled={clientId.locked}
                  helperText={
                    clientId.locked
                      ? 'Server client id is fixed; a role suffix is added when this identifier is already used on the display.'
                      : 'Unique per API key on this display (suggested value includes the role when needed).'
                  }
                />
                <FormControl fullWidth>
                  <InputLabel id="issue-role-label">Role</InputLabel>
                  <Select
                    labelId="issue-role-label"
                    label="Role"
                    value={issueRole}
                    onChange={(e) => setIssueRole(e.target.value)}
                  >
                    {API_CLIENT_ROLES.map((r) => (
                      <MenuItem key={r.value} value={r.value}>
                        {r.label}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </>
            )}
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setIssueOpen(false)}>{issuedKey ? 'Done' : 'Cancel'}</Button>
          {!issuedKey && (
            <Button
              variant="contained"
              disabled={issueBusy || issueIdentifier.trim().length === 0}
              onClick={() => void submitIssue()}
            >
              Issue key
            </Button>
          )}
        </DialogActions>
      </Dialog>
    </Box>
  );
}

function DisplayAdoptionSettingsSection({ display }: { display: SavedDisplay }) {
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [initialized, setInitialized] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [allowedRoles, setAllowedRoles] = useState<Set<string>>(() => new Set());
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    await wrapRefresh(async () => {
      setError(null);
      try {
        const data = await apiJson<CuratorDisplaySettings>(display, '/v1/curator/settings');
        setAllowedRoles(parseAdoptionAllowedRoles(data));
        setInitialized(true);
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    });
  }, [display, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load]);

  const toggleRole = (role: string, checked: boolean) => {
    setAllowedRoles((prev) => {
      const next = new Set(prev);
      if (checked) {
        next.add(role);
      } else {
        next.delete(role);
      }
      return next;
    });
  };

  const save = async () => {
    setError(null);
    setSaved(false);
    setBusy(true);
    try {
      await apiJson(display, '/v1/curator/settings', {
        method: 'PUT',
        body: JSON.stringify({
          adoption_allowed_roles: ADOPTION_ROLES.map((r) => r.value).filter((role) =>
            allowedRoles.has(role),
          ),
        }),
      });
      setSaved(true);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setBusy(false);
    }
  };

  if (!initialized && loading) {
    return (
      <Stack spacing={1}>
        <DisplayRefreshIndicator loading={loading} />
        <Typography variant="body2" color="text.secondary">
          Loading adoption settings…
        </Typography>
      </Stack>
    );
  }

  return (
    <Box>
      <DisplayRefreshIndicator loading={loading} />
      <Typography variant="subtitle1" fontWeight={600} gutterBottom>
        Controller adoption
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Choose which roles may start new adoption challenges from other controllers. Uncheck all
        roles to block public pairing; existing adopted sessions keep working and display admins
        can still grant access with an API key.
      </Typography>
      {error && (
        <Alert severity="error" sx={{ mb: 1 }}>
          {error}
        </Alert>
      )}
      {saved && (
        <Alert severity="success" sx={{ mb: 1 }} onClose={() => setSaved(false)}>
          Saved.
        </Alert>
      )}
      <Stack spacing={0.5}>
        {ADOPTION_ROLES.map(({ value, label }) => (
          <FormControlLabel
            key={value}
            control={
              <Checkbox
                checked={allowedRoles.has(value)}
                disabled={busy}
                onChange={(_, checked) => toggleRole(value, checked)}
              />
            }
            label={`Allow ${label} adoption requests`}
          />
        ))}
      </Stack>
      <Box sx={{ mt: 2 }}>
        <Button variant="contained" disabled={busy} onClick={() => void save()}>
          Save adoption settings
        </Button>
      </Box>
    </Box>
  );
}

function CuratorDisplaySettingsSection({
  display,
  canWrite,
  kvWriteTick,
}: {
  display: SavedDisplay;
  canWrite: boolean;
  kvWriteTick: number;
}) {
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [initialized, setInitialized] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [form, setForm] = useState<CuratorDisplaySettings | null>(null);
  const [tickerSampleActive, setTickerSampleActive] = useState(false);

  const timezoneOptions = useMemo(
    () => (form ? displayTimezoneSelectOptions(form.display_timezone) : []),
    [form],
  );

  const selectedTimezone = useMemo((): DisplayTimezoneOption | null => {
    if (!form) return null;
    return (
      timezoneOptions.find((o) => o.id === form.display_timezone) ?? {
        id: form.display_timezone,
        label: `${form.display_timezone} (custom)`,
      }
    );
  }, [form, timezoneOptions]);

  const load = useCallback(async () => {
    await wrapRefresh(async () => {
      setError(null);
      try {
        const data = await apiJson<CuratorDisplaySettings>(display, '/v1/curator/settings');
        const tz =
          typeof data.display_timezone === 'string' && data.display_timezone.trim() !== ''
            ? data.display_timezone.trim()
            : 'America/New_York';
        const duration = clampNumber(
          data.program_duration_seconds ?? CURATOR_PROGRAM_DURATION.default,
          CURATOR_PROGRAM_DURATION.min,
          CURATOR_PROGRAM_DURATION.max,
        );
        const depth = clampNumber(
          data.history_depth ?? CURATOR_HISTORY_DEPTH.default,
          CURATOR_HISTORY_DEPTH.min,
          CURATOR_HISTORY_DEPTH.max,
        );
        const tickerPx = String(parseTickerPixelsPerSecond(data.ticker_pixels_per_second ?? ''));
        setForm({
          ...data,
          display_timezone: tz,
          program_duration_seconds: duration,
          history_depth: depth,
          ticker_pixels_per_second: tickerPx,
        });
        setInitialized(true);
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    });
  }, [display, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load, kvWriteTick]);

  const save = async () => {
    if (!form) return;
    setError(null);
    setSaved(false);
    try {
      await apiJson(display, '/v1/curator/settings', {
        method: 'PUT',
        body: JSON.stringify({
          program_duration_seconds: form.program_duration_seconds,
          history_depth: form.history_depth,
          ticker_pixels_per_second: form.ticker_pixels_per_second,
          display_theme_id: form.display_theme_id,
          display_text_scale_screen: form.display_text_scale_screen,
          display_text_scale_ticker: form.display_text_scale_ticker,
          display_timezone: form.display_timezone,
        }),
      });
      setSaved(true);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  if ((!initialized && loading) || !form) {
    return (
      <Stack spacing={1}>
        <DisplayRefreshIndicator loading={loading} />
        <Typography variant="body2" color="text.secondary">
          Loading display and curator tuning…
        </Typography>
      </Stack>
    );
  }

  return (
    <Box>
      <DisplayRefreshIndicator loading={loading} />
      <Typography variant="subtitle1" fontWeight={600} gutterBottom>
        Display and curator tuning
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Program timing, ticker speed, typography, and wall-clock timezone for calendars. News photo
        requirement is on the <strong>Categories</strong> tab.
      </Typography>
      {error && (
        <Alert severity="error" sx={{ mb: 1 }}>
          {error}
        </Alert>
      )}
      {saved && (
        <Alert severity="success" sx={{ mb: 1 }} onClose={() => setSaved(false)}>
          Saved.
        </Alert>
      )}
      <Stack spacing={2.5}>
        <CuratorSliderField
          label="Program duration"
          value={form.program_duration_seconds}
          min={CURATOR_PROGRAM_DURATION.min}
          max={CURATOR_PROGRAM_DURATION.max}
          step={CURATOR_PROGRAM_DURATION.step}
          disabled={!canWrite}
          formatValue={formatProgramDurationWithSeconds}
          onChange={(program_duration_seconds) => setForm({ ...form, program_duration_seconds })}
        />
        <CuratorSliderField
          label="History depth"
          value={form.history_depth}
          min={CURATOR_HISTORY_DEPTH.min}
          max={CURATOR_HISTORY_DEPTH.max}
          step={CURATOR_HISTORY_DEPTH.step}
          disabled={!canWrite}
          onChange={(history_depth) => setForm({ ...form, history_depth })}
        />
        <Box>
          <Stack direction="row" spacing={1} alignItems="flex-start">
            <Box sx={{ flex: 1, minWidth: 0 }}>
              <CuratorSliderField
                label="Ticker pixels per second"
                value={parseTickerPixelsPerSecond(form.ticker_pixels_per_second)}
                min={CURATOR_TICKER_PIXELS_PER_SECOND.min}
                max={CURATOR_TICKER_PIXELS_PER_SECOND.max}
                step={CURATOR_TICKER_PIXELS_PER_SECOND.step}
                disabled={!canWrite}
                formatValue={(v) => `${v} px/s`}
                onChange={(v) =>
                  setForm({ ...form, ticker_pixels_per_second: String(v) })
                }
              />
            </Box>
            <Button
              variant={tickerSampleActive ? 'contained' : 'outlined'}
              size="small"
              sx={{ mt: 3.25, flexShrink: 0 }}
              onClick={() => setTickerSampleActive((active) => !active)}
            >
              {tickerSampleActive ? 'Stop sample' : 'Play sample'}
            </Button>
          </Stack>
          {tickerSampleActive && (
            <TickerMarqueeSamplePreview
              pixelsPerSecond={parseTickerPixelsPerSecond(form.ticker_pixels_per_second)}
            />
          )}
        </Box>
        <Box>
          <Autocomplete
            fullWidth
            disabled={!canWrite}
            options={timezoneOptions}
            value={selectedTimezone}
            onChange={(_, option) => {
              if (option) setForm({ ...form, display_timezone: option.id });
            }}
            getOptionLabel={(option) => option.label}
            isOptionEqualToValue={(a, b) => a.id === b.id}
            filterOptions={(options, state) =>
              filterDisplayTimezoneOptions(options, state.inputValue)
            }
            renderInput={(params) => <TextField {...params} label="Display timezone" />}
          />
          <Typography variant="caption" color="text.secondary" sx={{ mt: 0.75, display: 'block' }}>
            Stored as <code>display.timezone</code>. Invalid ids fall back on the display. Type to
            filter {timezoneOptions.length} IANA zones.
          </Typography>
        </Box>
        <FormControl fullWidth disabled={!canWrite}>
          <InputLabel id="theme-label">Display theme</InputLabel>
          <Select
            labelId="theme-label"
            label="Display theme"
            value={form.display_theme_id}
            onChange={(e) => setForm({ ...form, display_theme_id: String(e.target.value) })}
            renderValue={(value) => {
              const theme = curatorThemeById(String(value));
              if (!theme) {
                return value;
              }
              return (
                <Stack
                  direction="row"
                  alignItems="center"
                  spacing={1}
                  sx={{ width: '100%', pr: 0.5 }}
                >
                  <Box component="span" sx={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {theme.label}
                  </Box>
                  <DisplayThemePaletteSwatches colors={theme.colors} />
                </Stack>
              );
            }}
          >
            {curatorThemeIds.map((t) => (
              <MenuItem key={t.id} value={t.id} sx={{ gap: 1 }}>
                <Box component="span" sx={{ flex: 1 }}>
                  {t.label}
                </Box>
                <DisplayThemePaletteSwatches colors={t.colors} />
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        <FormControl fullWidth disabled={!canWrite}>
          <InputLabel id="screen-scale">Screen text scale</InputLabel>
          <Select
            labelId="screen-scale"
            label="Screen text scale"
            value={form.display_text_scale_screen}
            onChange={(e) => setForm({ ...form, display_text_scale_screen: String(e.target.value) })}
          >
            {curatorTextScaleIds.map((id) => (
              <MenuItem key={id} value={id}>
                {id}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        <FormControl fullWidth disabled={!canWrite}>
          <InputLabel id="ticker-scale">Ticker text scale</InputLabel>
          <Select
            labelId="ticker-scale"
            label="Ticker text scale"
            value={form.display_text_scale_ticker}
            onChange={(e) => setForm({ ...form, display_text_scale_ticker: String(e.target.value) })}
          >
            {curatorTextScaleIds.map((id) => (
              <MenuItem key={`t-${id}`} value={id}>
                {id}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        {canWrite && (
          <Button variant="contained" onClick={() => void save()}>
            Save display and curator tuning
          </Button>
        )}
      </Stack>
    </Box>
  );
}

type KvRow = { key: string; value: string };

function AdvancedConfigKeyValuesSection({
  display,
  canWrite,
  embedded = false,
  onApplied,
}: {
  display: SavedDisplay;
  canWrite: boolean;
  /** When true, omit the section title (parent accordion provides it). */
  embedded?: boolean;
  onApplied: () => void;
}) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [savedMsg, setSavedMsg] = useState<string | null>(null);
  const [rows, setRows] = useState<KvRow[]>([]);
  const [initialKeys, setInitialKeys] = useState<Set<string>>(() => new Set());

  const loadRows = useCallback(async () => {
    setLoading(true);
    setError(null);
    setSavedMsg(null);
    try {
      const body = await apiJson<{ items: { key: string; value: string }[] }>(
        display,
        '/v1/config/key-values',
      );
      const next = (body.items ?? []).map((r: { key: string; value: string }) => ({
        key: r.key,
        value: r.value,
      }));
      setRows(next);
      setInitialKeys(new Set(next.map((r) => r.key)));
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setLoading(false);
    }
  }, [display]);

  useEffect(() => {
    void loadRows();
  }, [loadRows]);

  const applyChanges = async () => {
    setError(null);
    setSavedMsg(null);
    const trimmed = rows.map((r) => ({ key: r.key.trim(), value: r.value }));
    for (const r of trimmed) {
      if (!r.key && r.value.trim() !== '') {
        setError('Each value needs a non-empty key, or clear the value on unused rows.');
        return;
      }
    }
    const activeRows = trimmed.filter((r) => r.key.length > 0);
    const keys = activeRows.map((r) => r.key);
    if (new Set(keys).size !== keys.length) {
      setError('Duplicate keys are not allowed.');
      return;
    }
    const nextMap = new Map(activeRows.map((r) => [r.key, r.value]));
    try {
      for (const k of initialKeys) {
        if (!nextMap.has(k)) {
          await apiFetch(
            display,
            `/v1/config/key-values?key=${encodeURIComponent(k)}`,
            { method: 'DELETE' },
          );
        }
      }
      for (const [key, value] of nextMap) {
        await apiFetch(display, '/v1/config/key-values', {
          method: 'PUT',
          body: JSON.stringify({ key, value }),
        });
      }
      setSavedMsg('Key–value changes applied.');
      setInitialKeys(new Set(nextMap.keys()));
      onApplied();
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  return (
    <Box>
      {!embedded && (
        <Typography variant="subtitle1" fontWeight={600} gutterBottom>
          Advanced: config key–values
        </Typography>
      )}
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Direct access to SQLite <code>config_key_values</code> (curator defaults, theme, ticker copy,{' '}
        <code>display.timezone</code>, etc.). Use carefully; invalid keys can confuse the display.
      </Typography>
      {error && (
        <Alert severity="error" sx={{ mb: 1 }}>
          {error}
        </Alert>
      )}
      {savedMsg && (
        <Alert severity="success" sx={{ mb: 1 }} onClose={() => setSavedMsg(null)}>
          {savedMsg}
        </Alert>
      )}
      {loading && <Typography variant="body2">Loading keys…</Typography>}
      {!loading && (
        <Stack spacing={2}>
          {rows.map((row, idx) => (
            <Stack key={idx} direction="row" spacing={1} alignItems="flex-start">
              <TextField
                label="Key"
                value={row.key}
                disabled={!canWrite}
                onChange={(e) => {
                  const v = e.target.value;
                  setRows((prev) => prev.map((p, i) => (i === idx ? { ...p, key: v } : p)));
                }}
                fullWidth
                size="small"
              />
              <TextField
                label="Value"
                value={row.value}
                disabled={!canWrite}
                onChange={(e) => {
                  const v = e.target.value;
                  setRows((prev) => prev.map((p, i) => (i === idx ? { ...p, value: v } : p)));
                }}
                fullWidth
                size="small"
              />
              <IconButton
                aria-label="Remove row"
                disabled={!canWrite}
                onClick={() => setRows((prev) => prev.filter((_, i) => i !== idx))}
                sx={{ mt: 0.5 }}
              >
                <DeleteOutlineIcon />
              </IconButton>
            </Stack>
          ))}
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Button
              size="small"
              variant="outlined"
              disabled={!canWrite}
              onClick={() => setRows((prev) => [...prev, { key: '', value: '' }])}
            >
              Add row
            </Button>
            <Button size="small" variant="outlined" disabled={!canWrite} onClick={() => void loadRows()}>
              Reload from display
            </Button>
            {canWrite && (
              <Button size="small" variant="contained" onClick={() => void applyChanges()}>
                Apply changes
              </Button>
            )}
          </Stack>
        </Stack>
      )}
    </Box>
  );
}
