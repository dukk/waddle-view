import { useCallback, useEffect, useRef, useState } from 'react';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import {
  Alert,
  Box,
  Button,
  Divider,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  Tab,
  Tabs,
  TextField,
  Typography,
} from '@mui/material';
import {
  exportDisplaysJson,
  importDisplaysJson,
  importDisplaysJsonLegacy,
  type SavedDisplay,
} from '@/storage/displays';
import { useAuth } from '@/context/AuthContext';
import { useControllerAuth } from '@/context/ControllerAuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import {
  curatorThemeIds,
  curatorTextScaleIds,
  type CuratorDisplaySettings,
} from '@/constants/curatorDisplaySettings';
import { ControllerAccessSection } from '@/components/ControllerAccessSection';

const SETTINGS_TABS = [
  { id: 'general', label: 'General' },
  { id: 'controller', label: 'Controller' },
  { id: 'display', label: 'Display' },
  { id: 'backup', label: 'Backup' },
] as const;

type SettingsTabId = (typeof SETTINGS_TABS)[number]['id'];

export function SettingsPage() {
  const { active, refresh } = useDisplay();
  const { hasPermission, session } = useAuth();
  const { status: bffStatus } = useControllerAuth();
  const [tab, setTab] = useState<SettingsTabId>('general');
  const [kvWriteTick, setKvWriteTick] = useState(0);
  const [importText, setImportText] = useState('');
  const [msg, setMsg] = useState<{ level: 'success' | 'error'; text: string } | null>(null);
  const showDisplaySettings = Boolean(active && hasPermission('curator.read'));
  const fileRef = useRef<HTMLInputElement>(null);
  const exportBlob = () => {
    const blob = new Blob([exportDisplaysJson()], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'waddle_controller_displays.json';
    a.click();
    URL.revokeObjectURL(url);
  };

  const doImport = () => {
    setMsg(null);
    try {
      try {
        importDisplaysJson(importText);
      } catch {
        importDisplaysJsonLegacy(importText);
      }
      setImportText('');
      refresh();
      setMsg({ level: 'success', text: 'Imported display list.' });
    } catch (e) {
      setMsg({ level: 'error', text: String(e) });
    }
  };

  return (
    <Stack spacing={2} sx={{ maxWidth: 720 }}>
      <Typography variant="h5" fontWeight={600}>
        Settings
      </Typography>

      {msg && (
        <Alert severity={msg.level} onClose={() => setMsg(null)}>
          {msg.text}
        </Alert>
      )}

      <Paper sx={{ px: 2, pt: 1 }}>
        <Tabs
          value={tab}
          onChange={(_, v) => setTab(v as SettingsTabId)}
          variant="scrollable"
          scrollButtons="auto"
          sx={{ borderBottom: 1, borderColor: 'divider' }}
        >
          {SETTINGS_TABS.map((t) => (
            <Tab key={t.id} label={t.label} value={t.id} />
          ))}
        </Tabs>
      </Paper>

      <Paper sx={{ p: 2 }}>
        {tab === 'general' && (
          <Stack spacing={2}>
            {session && (
              <Alert severity="info">
                Adopted as <strong>{session.identifier}</strong> ({session.role}).
                {bffStatus?.authEnabled && (
                  <>
                    {' '}
                    Open <strong>Account</strong> from the user menu for session details and
                    appearance.
                  </>
                )}
              </Alert>
            )}
            <Alert severity="info">
              <strong>Keyboard shortcuts</strong> (when focus is not in a text field): Left/Right
              arrows navigate the <strong>screen</strong> carousel; Up/Down navigate the{' '}
              <strong>ticker</strong>.
            </Alert>
          </Stack>
        )}

        {tab === 'controller' && <ControllerAccessSection />}

        {tab === 'display' && (
          <Stack spacing={3}>
            {!active && (
              <Alert severity="info">Select a display in the toolbar to edit display settings.</Alert>
            )}
            {active && !hasPermission('curator.read') && (
              <Alert severity="warning">
                Your adopted role does not include <strong>curator.read</strong>, so display tuning
                is not available.
              </Alert>
            )}
            {showDisplaySettings && active && (
              <>
                <CuratorDisplaySettingsSection
                  display={active}
                  canWrite={hasPermission('curator.write')}
                  kvWriteTick={kvWriteTick}
                />
                <Divider />
                <AdvancedConfigKeyValuesSection
                  display={active}
                  canWrite={hasPermission('curator.write')}
                  onApplied={() => setKvWriteTick((t) => t + 1)}
                />
              </>
            )}
          </Stack>
        )}

        {tab === 'backup' && (
          <Box>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Export or import the saved display list stored in this browser (base URLs and labels,
              not API keys).
            </Typography>
            <Stack direction="row" spacing={1} sx={{ mb: 2 }} flexWrap="wrap" useFlexGap>
              <Button variant="outlined" onClick={exportBlob}>
                Export JSON
              </Button>
              <Button variant="outlined" onClick={() => fileRef.current?.click()}>
                Import from file
              </Button>
              <input
                ref={fileRef}
                type="file"
                accept="application/json,.json"
                hidden
                onChange={async (ev) => {
                  const f = ev.target.files?.[0];
                  ev.target.value = '';
                  if (!f) return;
                  setImportText(await f.text());
                }}
              />
            </Stack>
            <TextField
              label="Paste JSON to import"
              value={importText}
              onChange={(e) => setImportText(e.target.value)}
              fullWidth
              multiline
              minRows={4}
            />
            <Button
              sx={{ mt: 1 }}
              variant="contained"
              onClick={doImport}
              disabled={!importText.trim()}
            >
              Apply import
            </Button>
          </Box>
        )}
      </Paper>
    </Stack>
  );
}

function CuratorDisplaySettingsSection({
  display,
  canWrite,
  kvWriteTick,
}: {
  display: SavedDisplay;
  canWrite: boolean;
  /** Incremented when SQLite `config_key_values` may have changed elsewhere on this page. */
  kvWriteTick: number;
}) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [form, setForm] = useState<CuratorDisplaySettings | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await apiJson<CuratorDisplaySettings>(display, '/v1/curator/settings');
      const tz =
        typeof data.display_timezone === 'string' && data.display_timezone.trim() !== ''
          ? data.display_timezone.trim()
          : 'America/New_York';
      setForm({ ...data, display_timezone: tz });
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setLoading(false);
    }
  }, [display]);

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

  if (loading || !form) {
    return <Typography variant="body2">Loading display and curator tuning…</Typography>;
  }

  return (
    <Box>
      <Typography variant="subtitle1" fontWeight={600} gutterBottom>
        Display and curator tuning
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Program timing, ticker speed, typography, and wall-clock timezone for calendars. News photo
        requirement stays on the <strong>Curators</strong> page.
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
      <Stack spacing={2} sx={{ maxWidth: 560 }}>
        <TextField
          label="Program duration (seconds)"
          type="number"
          disabled={!canWrite}
          value={form.program_duration_seconds}
          onChange={(e) =>
            setForm({ ...form, program_duration_seconds: Number(e.target.value) || 0 })
          }
          fullWidth
        />
        <TextField
          label="History depth"
          type="number"
          disabled={!canWrite}
          value={form.history_depth}
          onChange={(e) => setForm({ ...form, history_depth: Number(e.target.value) || 0 })}
          fullWidth
        />
        <TextField
          label="Ticker pixels per second"
          disabled={!canWrite}
          value={form.ticker_pixels_per_second}
          onChange={(e) => setForm({ ...form, ticker_pixels_per_second: e.target.value })}
          fullWidth
        />
        <TextField
          label="Display timezone (IANA)"
          disabled={!canWrite}
          value={form.display_timezone}
          onChange={(e) => setForm({ ...form, display_timezone: e.target.value })}
          fullWidth
          helperText="Stored as config key display.timezone (e.g. America/Chicago). Invalid ids fall back on the display."
        />
        <FormControl fullWidth disabled={!canWrite}>
          <InputLabel id="theme-label">Display theme</InputLabel>
          <Select
            labelId="theme-label"
            label="Display theme"
            value={form.display_theme_id}
            onChange={(e) => setForm({ ...form, display_theme_id: String(e.target.value) })}
          >
            {curatorThemeIds.map((t) => (
              <MenuItem key={t.id} value={t.id}>
                {t.label}
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
  onApplied,
}: {
  display: SavedDisplay;
  canWrite: boolean;
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
      <Typography variant="subtitle1" fontWeight={600} gutterBottom>
        Advanced: config key–values
      </Typography>
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
