import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Switch,
  TextField,
  Typography,
} from '@mui/material';
import { useDisplay } from '@/context/DisplayContext';
import { apiJson, ApiError } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';

const themeIds = [
  { id: 'navy_coral', label: 'Navy / coral (default)' },
  { id: 'graphite_amber', label: 'Graphite / amber' },
];

const textScaleIds = [
  'xxx-small',
  'xx-small',
  'x-small',
  'smaller',
  'small',
  'normal',
  'large',
  'larger',
  'x-large',
  'xx-large',
  'xxx-large',
];

type CuratorSettings = {
  program_duration_seconds: number;
  history_depth: number;
  ticker_pixels_per_second: string;
  require_news_photo_for_screens: boolean;
  display_theme_id: string;
  display_text_scale_screen: string;
  display_text_scale_ticker: string;
};

export function CuratorsPage() {
  const { active } = useDisplay();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [form, setForm] = useState<CuratorSettings | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    setLoading(true);
    setError(null);
    try {
      const data = await apiJson<CuratorSettings>(active, '/v1/curator/settings');
      setForm(data);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setLoading(false);
    }
  }, [active]);

  useEffect(() => {
    void load();
  }, [load]);

  const save = async () => {
    if (!active || !form) return;
    setError(null);
    setSaved(false);
    try {
      await apiJson(active, '/v1/curator/settings', {
        method: 'PUT',
        body: JSON.stringify(form),
      });
      setSaved(true);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  if (loading || !form) {
    return <Typography>Loading curator settings…</Typography>;
  }

  return (
    <Stack spacing={2} sx={{ maxWidth: 560 }}>
      <Typography variant="h5" fontWeight={600}>
        Curator
      </Typography>
      {error && <Alert severity="error">{error}</Alert>}
      {saved && <Alert severity="success">Saved.</Alert>}
      <TextField
        label="Program duration (seconds)"
        type="number"
        value={form.program_duration_seconds}
        onChange={(e) =>
          setForm({ ...form, program_duration_seconds: Number(e.target.value) || 0 })
        }
        fullWidth
      />
      <TextField
        label="History depth"
        type="number"
        value={form.history_depth}
        onChange={(e) => setForm({ ...form, history_depth: Number(e.target.value) || 0 })}
        fullWidth
      />
      <TextField
        label="Ticker pixels per second"
        value={form.ticker_pixels_per_second}
        onChange={(e) => setForm({ ...form, ticker_pixels_per_second: e.target.value })}
        fullWidth
      />
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        <Switch
          checked={form.require_news_photo_for_screens}
          onChange={(_, v) => setForm({ ...form, require_news_photo_for_screens: v })}
        />
        <Typography>Require news photo for screen slides</Typography>
      </Box>
      <FormControl fullWidth>
        <InputLabel id="theme-label">Display theme</InputLabel>
        <Select
          labelId="theme-label"
          label="Display theme"
          value={form.display_theme_id}
          onChange={(e) => setForm({ ...form, display_theme_id: String(e.target.value) })}
        >
          {themeIds.map((t) => (
            <MenuItem key={t.id} value={t.id}>
              {t.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <FormControl fullWidth>
        <InputLabel id="screen-scale">Screen text scale</InputLabel>
        <Select
          labelId="screen-scale"
          label="Screen text scale"
          value={form.display_text_scale_screen}
          onChange={(e) => setForm({ ...form, display_text_scale_screen: String(e.target.value) })}
        >
          {textScaleIds.map((id) => (
            <MenuItem key={id} value={id}>
              {id}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <FormControl fullWidth>
        <InputLabel id="ticker-scale">Ticker text scale</InputLabel>
        <Select
          labelId="ticker-scale"
          label="Ticker text scale"
          value={form.display_text_scale_ticker}
          onChange={(e) => setForm({ ...form, display_text_scale_ticker: String(e.target.value) })}
        >
          {textScaleIds.map((id) => (
            <MenuItem key={`t-${id}`} value={id}>
              {id}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <Button variant="contained" onClick={() => void save()}>
        Save settings
      </Button>
    </Stack>
  );
}
