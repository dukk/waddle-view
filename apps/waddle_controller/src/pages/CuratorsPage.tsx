import { useCallback, useEffect, useMemo, useState } from 'react';
import AddIcon from '@mui/icons-material/Add';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Checkbox,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  FormControlLabel,
  IconButton,
  InputLabel,
  MenuItem,
  Paper,
  Select,
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
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiJson, ApiError } from '@/api/client';
import {
  CURATOR_LAYERS,
  createCuratorConfiguration,
  deleteCuratorConfiguration,
  fetchActiveCurator,
  fetchCuratorConfiguration,
  fetchCuratorStatePredicates,
  listCuratorConfigurations,
  updateCuratorConfiguration,
  type ActiveCuratorMatch,
  type ActiveCuratorResponse,
  type CuratorConfigurationDetail,
  type CuratorConfigurationSummary,
  type CuratorConfigurationWriteBody,
  type CuratorLayer,
  type CuratorScheduleRule,
  type CuratorStatePredicateMeta,
} from '@/api/curatorConfigurations';
import { CuratorCategoriesSection } from '@/components/curator/CuratorCategoriesSection';
import { RejectTermsSection } from '@/components/curator/RejectTermsSection';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import type { SavedDisplay } from '@/storage/displays';

type CuratorsTabId = 'configurations' | 'categories' | 'reject-terms';

const LAYER_CHIP_COLOR: Record<CuratorLayer, 'error' | 'primary' | 'secondary'> = {
  exclusive: 'error',
  base: 'primary',
  enhancement: 'secondary',
};

function layerLabel(layer: CuratorLayer): string {
  return layer.charAt(0).toUpperCase() + layer.slice(1);
}

function minutesToTimeInput(minutes: number | null): string {
  if (minutes == null || !Number.isFinite(minutes)) return '';
  const h = Math.floor(minutes / 60) % 24;
  const m = minutes % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function timeInputToMinutes(value: string): number | null {
  const t = value.trim();
  if (!t) return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(t);
  if (!m) return null;
  const h = Number.parseInt(m[1]!, 10);
  const min = Number.parseInt(m[2]!, 10);
  if (h < 0 || h > 23 || min < 0 || min > 59) return null;
  return h * 60 + min;
}

function emptyRule(): Omit<CuratorScheduleRule, 'configuration_id'> {
  return {
    id: '',
    priority: 0,
    state_predicate: null,
    days_of_week_mask: null,
    start_time_minutes: null,
    end_time_minutes: null,
    start_month: null,
    start_day: null,
    end_month: null,
    end_day: null,
    repeat_annually: true,
    year_exact: null,
    nth_week_of_month: null,
    nth_weekday: null,
  };
}

function ActivePreviewCard({ active }: { active: ActiveCuratorResponse | null }) {
  if (!active) {
    return (
      <Typography variant="body2" color="text.secondary">
        No active curator resolution loaded.
      </Typography>
    );
  }
  const rows: ActiveCuratorMatch[] = [];
  if (active.exclusive) rows.push(active.exclusive);
  else if (active.base) rows.push(active.base);
  rows.push(...active.enhancements);
  if (rows.length === 0) {
    return (
      <Typography variant="body2" color="text.secondary">
        No configuration matched at the display&apos;s current local time.
      </Typography>
    );
  }
  return (
    <Stack spacing={1}>
      {rows.map((row) => (
        <Stack key={`${row.layer}-${row.configuration_id}`} direction="row" spacing={1} alignItems="center">
          <Chip size="small" label={layerLabel(row.layer)} color={LAYER_CHIP_COLOR[row.layer]} />
          <Typography variant="body2" fontWeight={600}>
            {row.configuration_name}
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'monospace' }}>
            {row.configuration_id}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            — {row.match_reason}
          </Typography>
        </Stack>
      ))}
    </Stack>
  );
}

export function CuratorsPage() {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const canCuratorRead = hasPermission('curator.read');
  const canCuratorWrite = hasPermission('curator.write');
  const canRejectTerms = hasPermission('reject_terms.manage');
  const [tab, setTab] = useState<CuratorsTabId>('configurations');

  const visibleTabs = useMemo(() => {
    const tabs: { id: CuratorsTabId; label: string }[] = [
      { id: 'configurations', label: 'Configurations' },
    ];
    if (canCuratorRead) tabs.push({ id: 'categories', label: 'Categories' });
    if (canRejectTerms) tabs.push({ id: 'reject-terms', label: 'Rejected terms' });
    return tabs;
  }, [canCuratorRead, canRejectTerms]);

  useEffect(() => {
    if (!visibleTabs.some((t) => t.id === tab)) {
      setTab(visibleTabs[0]!.id);
    }
  }, [visibleTabs, tab]);

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={2}>
      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          Curators — {active.label}
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Layered program configurations (exclusive, base, enhancement), schedule rules, and
          catalog membership. Categories and reject terms apply across all programs.
        </Typography>
      </Box>

      <Paper sx={{ px: 2, pt: 1 }}>
        <Tabs
          value={tab}
          onChange={(_, v) => setTab(v as CuratorsTabId)}
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
        {tab === 'configurations' && (
          <CuratorConfigurationsSection
            display={active}
            canRead={canCuratorRead}
            canWrite={canCuratorWrite}
          />
        )}
        {tab === 'categories' && (
          <>
            {!canCuratorRead && (
              <Alert severity="warning">
                Your adopted role does not include <strong>curator.read</strong>.
              </Alert>
            )}
            {canCuratorRead && (
              <CuratorCategoriesSection display={active} canWrite={canCuratorWrite} />
            )}
          </>
        )}
        {tab === 'reject-terms' && (
          <>
            {!canRejectTerms && (
              <Alert severity="warning">
                Your adopted role does not include <strong>reject_terms.manage</strong>.
              </Alert>
            )}
            {canRejectTerms && <RejectTermsSection display={active} />}
          </>
        )}
      </Paper>
    </Stack>
  );
}

function CuratorConfigurationsSection({
  display,
  canRead,
  canWrite,
}: {
  display: SavedDisplay;
  canRead: boolean;
  canWrite: boolean;
}) {
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [error, setError] = useState<string | null>(null);
  const [rows, setRows] = useState<CuratorConfigurationSummary[]>([]);
  const [activePreview, setActivePreview] = useState<ActiveCuratorResponse | null>(null);
  const [editId, setEditId] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);

  const load = useCallback(async () => {
    if (!canRead) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const [list, active] = await Promise.all([
          listCuratorConfigurations(display),
          fetchActiveCurator(display),
        ]);
        setRows(list.sort((a, b) => a.sort_order - b.sort_order || a.id.localeCompare(b.id)));
        setActivePreview(active);
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    });
  }, [canRead, display, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load]);

  const deleteConfig = async (id: string) => {
    if (!confirm(`Delete curator configuration "${id}"?`)) return;
    try {
      await deleteCuratorConfiguration(display, id);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  if (!canRead) {
    return (
      <Alert severity="warning">
        Your adopted role does not include <strong>curator.read</strong>, so curator
        configurations are not available.
      </Alert>
    );
  }

  return (
    <Stack spacing={3}>
      <DisplayRefreshIndicator loading={loading} />
      {error && <Alert severity="error">{error}</Alert>}

      <Box>
        <Typography variant="subtitle2" fontWeight={600} gutterBottom>
          Active now
        </Typography>
        <Paper variant="outlined" sx={{ p: 2 }}>
          <ActivePreviewCard active={activePreview} />
        </Paper>
      </Box>

      <Stack direction="row" justifyContent="space-between" alignItems="center">
        <Typography variant="subtitle2" fontWeight={600}>
          Configurations
        </Typography>
        {canWrite && (
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => setAddOpen(true)}>
            Add configuration
          </Button>
        )}
      </Stack>

      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Name</TableCell>
              <TableCell>ID</TableCell>
              <TableCell>Layer</TableCell>
              <TableCell>Sort</TableCell>
              <TableCell>Program</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((row) => (
              <TableRow key={row.id} hover>
                <TableCell sx={{ fontWeight: 600 }}>{row.name}</TableCell>
                <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>{row.id}</TableCell>
                <TableCell>
                  <Chip
                    size="small"
                    label={layerLabel(row.layer)}
                    color={LAYER_CHIP_COLOR[row.layer]}
                  />
                </TableCell>
                <TableCell>{row.sort_order}</TableCell>
                <TableCell>{row.program_duration_seconds}s · depth {row.history_depth}</TableCell>
                <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                  <Button size="small" onClick={() => setEditId(row.id)}>
                    Edit
                  </Button>
                  {canWrite && (
                    <Button size="small" color="error" onClick={() => void deleteConfig(row.id)}>
                      Delete
                    </Button>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {addOpen && (
        <CuratorConfigurationDialog
          display={display}
          canWrite={canWrite}
          onClose={() => setAddOpen(false)}
          onSaved={async () => {
            setAddOpen(false);
            await load();
          }}
        />
      )}
      {editId && (
        <CuratorConfigurationDialog
          display={display}
          canWrite={canWrite}
          configurationId={editId}
          onClose={() => setEditId(null)}
          onSaved={async () => {
            setEditId(null);
            await load();
          }}
        />
      )}
    </Stack>
  );
}

type CatalogOption = { id: string; label: string };

function CuratorConfigurationDialog({
  display,
  canWrite,
  configurationId,
  onClose,
  onSaved,
}: {
  display: SavedDisplay;
  canWrite: boolean;
  configurationId?: string;
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const isNew = configurationId == null;
  const [loading, setLoading] = useState(!isNew);
  const [err, setErr] = useState<string | null>(null);
  const [id, setId] = useState(configurationId ?? '');
  const [name, setName] = useState('');
  const [layer, setLayer] = useState<CuratorLayer>('base');
  const [sortOrder, setSortOrder] = useState(0);
  const [programDuration, setProgramDuration] = useState(180);
  const [historyDepth, setHistoryDepth] = useState(5);
  const [requireNewsPhoto, setRequireNewsPhoto] = useState(true);
  const [defaultConfig, setDefaultConfig] = useState(false);
  const [rules, setRules] = useState<Omit<CuratorScheduleRule, 'configuration_id'>[]>([]);
  const [screenIds, setScreenIds] = useState<string[]>([]);
  const [tickerIds, setTickerIds] = useState<string[]>([]);
  const [overlayIds, setOverlayIds] = useState<string[]>([]);
  const [predicates, setPredicates] = useState<CuratorStatePredicateMeta[]>([]);
  const [screenOptions, setScreenOptions] = useState<CatalogOption[]>([]);
  const [tickerOptions, setTickerOptions] = useState<CatalogOption[]>([]);
  const [overlayOptions, setOverlayOptions] = useState<CatalogOption[]>([]);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      setErr(null);
      try {
        const [preds, screens, tickers, overlays] = await Promise.all([
          fetchCuratorStatePredicates(display),
          apiJson<{ items: { id: string; name: string }[] }>(display, '/v1/screens'),
          apiJson<{ items: { id: string; name: string }[] }>(display, '/v1/ticker/tapes'),
          apiJson<{ items: { id: string; label: string }[] }>(display, '/v1/display/overlays'),
        ]);
        if (cancelled) return;
        setPredicates(preds);
        setScreenOptions(
          (screens.items ?? []).map((s) => ({
            id: s.id,
            label: s.name?.trim() ? `${s.name} (${s.id})` : s.id,
          })),
        );
        setTickerOptions(
          (tickers.items ?? []).map((t) => ({
            id: t.id,
            label: t.name?.trim() ? `${t.name} (${t.id})` : t.id,
          })),
        );
        setOverlayOptions(
          (overlays.items ?? []).map((o) => ({
            id: o.id,
            label: o.label?.trim() ? `${o.label} (${o.id})` : o.id,
          })),
        );
        if (configurationId) {
          const detail: CuratorConfigurationDetail = await fetchCuratorConfiguration(
            display,
            configurationId,
          );
          if (cancelled) return;
          setName(detail.name);
          setLayer(detail.layer);
          setSortOrder(detail.sort_order);
          setProgramDuration(detail.program_duration_seconds);
          setHistoryDepth(detail.history_depth);
          setRequireNewsPhoto(detail.require_news_photo_for_screens);
          setDefaultConfig(detail.default_config);
          setRules(
            detail.rules.map((r) => ({
              id: r.id,
              priority: r.priority,
              state_predicate: r.state_predicate,
              days_of_week_mask: r.days_of_week_mask,
              start_time_minutes: r.start_time_minutes,
              end_time_minutes: r.end_time_minutes,
              start_month: r.start_month,
              start_day: r.start_day,
              end_month: r.end_month,
              end_day: r.end_day,
              repeat_annually: r.repeat_annually,
              year_exact: r.year_exact,
              nth_week_of_month: r.nth_week_of_month,
              nth_weekday: r.nth_weekday,
            })),
          );
          setScreenIds(detail.members.screens ?? []);
          setTickerIds(detail.members.tickers ?? []);
          setOverlayIds(detail.members.overlays ?? []);
        }
      } catch (e) {
        if (!cancelled) {
          setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [configurationId, display]);

  const showProgramFields = layer === 'base' || layer === 'exclusive';
  const membersOverlayOnly = layer === 'enhancement';

  const buildBody = (): CuratorConfigurationWriteBody => ({
    name: name.trim(),
    layer,
    sort_order: sortOrder,
    program_duration_seconds: programDuration,
    history_depth: historyDepth,
    require_news_photo_for_screens: requireNewsPhoto,
    default_config: defaultConfig,
    rules: rules.map((r) => ({
      ...r,
      id: r.id.trim(),
      configuration_id: configurationId ?? id.trim(),
    })),
    members: membersOverlayOnly
      ? { screens: [], tickers: [], overlays: overlayIds }
      : { screens: screenIds, tickers: tickerIds, overlays: overlayIds },
  });

  const save = async () => {
    if (!canWrite) return;
    setErr(null);
    const tid = id.trim();
    if (isNew && !tid) {
      setErr('Configuration id is required.');
      return;
    }
    if (!name.trim()) {
      setErr('Name is required.');
      return;
    }
    try {
      if (isNew) {
        await createCuratorConfiguration(display, { id: tid, ...buildBody() });
      } else {
        await updateCuratorConfiguration(display, configurationId!, buildBody());
      }
      await onSaved();
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  const updateRule = (
    index: number,
    patch: Partial<Omit<CuratorScheduleRule, 'configuration_id'>>,
  ) => {
    setRules((prev) => prev.map((r, i) => (i === index ? { ...r, ...patch } : r)));
  };

  return (
    <Dialog open fullWidth maxWidth="md" onClose={onClose}>
      <DialogTitle>{isNew ? 'Add curator configuration' : `Edit ${configurationId}`}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {err && <Alert severity="error">{err}</Alert>}
          {loading ? (
            <Typography color="text.secondary">Loading…</Typography>
          ) : (
            <>
              {isNew && (
                <TextField
                  label="Configuration id"
                  value={id}
                  onChange={(e) => setId(e.target.value)}
                  required
                  fullWidth
                  helperText="Lowercase slug, e.g. morning or weekend_party"
                />
              )}
              <TextField label="Name" value={name} onChange={(e) => setName(e.target.value)} fullWidth />
              <FormControl fullWidth>
                <InputLabel id="curator-layer">Layer</InputLabel>
                <Select
                  labelId="curator-layer"
                  label="Layer"
                  value={layer}
                  onChange={(e) => setLayer(e.target.value as CuratorLayer)}
                  disabled={!canWrite}
                >
                  {CURATOR_LAYERS.map((l) => (
                    <MenuItem key={l} value={l}>
                      {layerLabel(l)}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
              <TextField
                label="Sort order"
                type="number"
                value={sortOrder}
                onChange={(e) => setSortOrder(Number(e.target.value) || 0)}
                fullWidth
              />
              <FormControlLabel
                control={
                  <Checkbox
                    checked={defaultConfig}
                    onChange={(_, v) => setDefaultConfig(v)}
                    disabled={!canWrite}
                  />
                }
                label="Default fallback (when no schedule rule matches)"
              />
              {showProgramFields && (
                <>
                  <Typography variant="subtitle2" fontWeight={600}>
                    Program settings
                  </Typography>
                  <TextField
                    label="Program duration (seconds)"
                    type="number"
                    value={programDuration}
                    onChange={(e) => setProgramDuration(Number(e.target.value) || 0)}
                    fullWidth
                  />
                  <TextField
                    label="History depth"
                    type="number"
                    value={historyDepth}
                    onChange={(e) => setHistoryDepth(Number(e.target.value) || 0)}
                    fullWidth
                  />
                  <FormControlLabel
                    control={
                      <Checkbox
                        checked={requireNewsPhoto}
                        onChange={(_, v) => setRequireNewsPhoto(v)}
                        disabled={!canWrite}
                      />
                    }
                    label="Require news photo for RSS screens"
                  />
                </>
              )}
              <Typography variant="subtitle2" fontWeight={600}>
                {membersOverlayOnly ? 'Overlay members' : 'Catalog members'}
              </Typography>
              {membersOverlayOnly ? (
                <MemberAutocomplete
                  label="Overlays"
                  options={overlayOptions}
                  value={overlayIds}
                  onChange={setOverlayIds}
                  disabled={!canWrite}
                />
              ) : (
                <Stack spacing={1.5}>
                  <MemberAutocomplete
                    label="Screens"
                    options={screenOptions}
                    value={screenIds}
                    onChange={setScreenIds}
                    disabled={!canWrite}
                  />
                  <MemberAutocomplete
                    label="Ticker tapes"
                    options={tickerOptions}
                    value={tickerIds}
                    onChange={setTickerIds}
                    disabled={!canWrite}
                  />
                  <MemberAutocomplete
                    label="Overlays"
                    options={overlayOptions}
                    value={overlayIds}
                    onChange={setOverlayIds}
                    disabled={!canWrite}
                  />
                </Stack>
              )}
              <Stack direction="row" alignItems="center" justifyContent="space-between">
                <Typography variant="subtitle2" fontWeight={600}>
                  Schedule rules
                </Typography>
                {canWrite && (
                  <Button
                    size="small"
                    onClick={() =>
                      setRules((prev) => [
                        ...prev,
                        { ...emptyRule(), id: `rule_${prev.length + 1}` },
                      ])
                    }
                  >
                    Add rule
                  </Button>
                )}
              </Stack>
              {rules.length === 0 ? (
                <Typography variant="body2" color="text.secondary">
                  No rules — configuration matches only when marked default fallback.
                </Typography>
              ) : (
                rules.map((rule, index) => (
                  <Paper key={index} variant="outlined" sx={{ p: 2 }}>
                    <Stack spacing={1.5}>
                      <Stack direction="row" spacing={1} alignItems="center">
                        <TextField
                          label="Rule id"
                          size="small"
                          value={rule.id}
                          onChange={(e) => updateRule(index, { id: e.target.value })}
                          sx={{ flex: 1 }}
                          disabled={!canWrite}
                        />
                        <TextField
                          label="Priority"
                          size="small"
                          type="number"
                          value={rule.priority}
                          onChange={(e) =>
                            updateRule(index, { priority: Number(e.target.value) || 0 })
                          }
                          sx={{ width: 100 }}
                          disabled={!canWrite}
                        />
                        {canWrite && (
                          <IconButton
                            aria-label="Remove rule"
                            color="error"
                            onClick={() => setRules((prev) => prev.filter((_, i) => i !== index))}
                          >
                            <DeleteOutlineIcon />
                          </IconButton>
                        )}
                      </Stack>
                      <FormControl fullWidth size="small">
                        <InputLabel id={`pred-${index}`}>State predicate</InputLabel>
                        <Select
                          labelId={`pred-${index}`}
                          label="State predicate"
                          value={rule.state_predicate ?? ''}
                          onChange={(e) =>
                            updateRule(index, {
                              state_predicate: e.target.value ? String(e.target.value) : null,
                            })
                          }
                          disabled={!canWrite}
                        >
                          <MenuItem value="">
                            <em>None (calendar / time only)</em>
                          </MenuItem>
                          {predicates.map((p) => (
                            <MenuItem key={p.id} value={p.id} disabled={!p.implemented}>
                              {p.label}
                              {!p.implemented ? ' (not wired)' : ''}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
                        <TextField
                          label="Start time"
                          size="small"
                          placeholder="HH:MM"
                          value={minutesToTimeInput(rule.start_time_minutes)}
                          onChange={(e) =>
                            updateRule(index, {
                              start_time_minutes: timeInputToMinutes(e.target.value),
                            })
                          }
                          disabled={!canWrite}
                          fullWidth
                        />
                        <TextField
                          label="End time"
                          size="small"
                          placeholder="HH:MM"
                          value={minutesToTimeInput(rule.end_time_minutes)}
                          onChange={(e) =>
                            updateRule(index, {
                              end_time_minutes: timeInputToMinutes(e.target.value),
                            })
                          }
                          disabled={!canWrite}
                          fullWidth
                        />
                      </Stack>
                      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
                        <TextField
                          label="Start month"
                          size="small"
                          type="number"
                          inputProps={{ min: 1, max: 12 }}
                          value={rule.start_month ?? ''}
                          onChange={(e) =>
                            updateRule(index, {
                              start_month: e.target.value ? Number(e.target.value) : null,
                            })
                          }
                          disabled={!canWrite}
                          fullWidth
                        />
                        <TextField
                          label="Start day"
                          size="small"
                          type="number"
                          inputProps={{ min: 1, max: 31 }}
                          value={rule.start_day ?? ''}
                          onChange={(e) =>
                            updateRule(index, {
                              start_day: e.target.value ? Number(e.target.value) : null,
                            })
                          }
                          disabled={!canWrite}
                          fullWidth
                        />
                        <TextField
                          label="End month"
                          size="small"
                          type="number"
                          inputProps={{ min: 1, max: 12 }}
                          value={rule.end_month ?? ''}
                          onChange={(e) =>
                            updateRule(index, {
                              end_month: e.target.value ? Number(e.target.value) : null,
                            })
                          }
                          disabled={!canWrite}
                          fullWidth
                        />
                        <TextField
                          label="End day"
                          size="small"
                          type="number"
                          inputProps={{ min: 1, max: 31 }}
                          value={rule.end_day ?? ''}
                          onChange={(e) =>
                            updateRule(index, {
                              end_day: e.target.value ? Number(e.target.value) : null,
                            })
                          }
                          disabled={!canWrite}
                          fullWidth
                        />
                      </Stack>
                      <FormControlLabel
                        control={
                          <Checkbox
                            checked={rule.repeat_annually}
                            onChange={(_, v) => updateRule(index, { repeat_annually: v })}
                            disabled={!canWrite}
                          />
                        }
                        label="Repeat annually"
                      />
                    </Stack>
                  </Paper>
                ))
              )}
            </>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        {canWrite && (
          <Button variant="contained" onClick={() => void save()} disabled={loading}>
            Save
          </Button>
        )}
      </DialogActions>
    </Dialog>
  );
}

function MemberAutocomplete({
  label,
  options,
  value,
  onChange,
  disabled,
}: {
  label: string;
  options: CatalogOption[];
  value: string[];
  onChange: (ids: string[]) => void;
  disabled?: boolean;
}) {
  const selected = options.filter((o) => value.includes(o.id));
  return (
    <Autocomplete
      multiple
      options={options}
      value={selected}
      onChange={(_, v) => onChange(v.map((o) => o.id))}
      getOptionLabel={(o) => o.label}
      isOptionEqualToValue={(a, b) => a.id === b.id}
      renderInput={(params) => <TextField {...params} label={label} />}
      disabled={disabled}
    />
  );
}
