import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
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
import { useDisplay } from '@/context/DisplayContext';
import { apiJson, ApiError } from '@/api/client';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';

type Line = { at_ms: number; channel: string; message: string };

function formatAtMs(atMs: number): string {
  const d = new Date(atMs);
  if (Number.isNaN(d.getTime())) {
    return String(atMs);
  }
  try {
    return new Intl.DateTimeFormat(undefined, {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      fractionalSecondDigits: 3,
    }).format(d);
  } catch {
    return d.toLocaleString();
  }
}

export function ActivityPage() {
  const { active } = useDisplay();
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [items, setItems] = useState<Line[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [filterText, setFilterText] = useState('');
  const [channelFilter, setChannelFilter] = useState<string>('');

  const channels = useMemo(() => {
    const set = new Set<string>();
    for (const row of items) {
      if (row.channel) set.add(row.channel);
    }
    return [...set].sort((a, b) => a.localeCompare(b));
  }, [items]);

  const filteredRows = useMemo(() => {
    const newestFirst = [...items].reverse();
    const q = filterText.trim().toLowerCase();
    return newestFirst.filter((row) => {
      if (channelFilter && row.channel !== channelFilter) return false;
      if (!q) return true;
      const timeStr = formatAtMs(row.at_ms).toLowerCase();
      return (
        row.message.toLowerCase().includes(q) ||
        row.channel.toLowerCase().includes(q) ||
        String(row.at_ms).includes(q) ||
        timeStr.includes(q)
      );
    });
  }, [items, filterText, channelFilter]);

  useEffect(() => {
    if (channelFilter && !channels.includes(channelFilter)) {
      setChannelFilter('');
    }
  }, [channels, channelFilter]);

  const load = useCallback(async () => {
    if (!active) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const res = await apiJson<{ items: Line[] }>(active, '/v1/telemetry/integrations?limit=300');
        setItems(res.items ?? []);
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    });
  }, [active, wrapRefresh]);

  useEffect(() => {
    void load();
    const id = window.setInterval(() => void load(), 4000);
    return () => window.clearInterval(id);
  }, [load]);

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={2}>
      <DisplayRefreshIndicator loading={loading} />
      <Typography variant="h5" fontWeight={600}>
        Live integration log
      </Typography>
      <Typography variant="body2" color="text.secondary">
        Live integration and engine log from the active display (refreshes about every four seconds).
        Filter by channel or message text to trace collector errors, curation, and runtime events.
      </Typography>
      {error && <Alert severity="error">{error}</Alert>}
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }}>
        <TextField
          label="Filter"
          placeholder="Message, channel, time, or at_ms"
          value={filterText}
          onChange={(e) => setFilterText(e.target.value)}
          size="small"
          sx={{ minWidth: { sm: 260 }, flex: 1 }}
        />
        <FormControl size="small" sx={{ minWidth: 180 }}>
          <InputLabel id="activity-channel-filter-label">Channel</InputLabel>
          <Select
            labelId="activity-channel-filter-label"
            label="Channel"
            value={channelFilter}
            onChange={(e) => setChannelFilter(e.target.value)}
          >
            <MenuItem value="">
              <em>All</em>
            </MenuItem>
            {channels.map((c) => (
              <MenuItem key={c} value={c}>
                {c}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      </Stack>
      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell width={200}>Time</TableCell>
              <TableCell width={100}>Channel</TableCell>
              <TableCell>Message</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredRows.map((row, i) => (
              <TableRow
                key={`${row.at_ms}-${row.channel}-${i}-${row.message.slice(0, 48)}`}
                title={String(row.at_ms)}
              >
                <TableCell sx={{ whiteSpace: 'nowrap' }}>{formatAtMs(row.at_ms)}</TableCell>
                <TableCell>{row.channel}</TableCell>
                <TableCell sx={{ fontFamily: 'monospace', fontSize: 12, whiteSpace: 'pre-wrap' }}>
                  {row.message}
                </TableCell>
              </TableRow>
            ))}
            {items.length === 0 && (
              <TableRow>
                <TableCell colSpan={3}>No telemetry lines yet.</TableCell>
              </TableRow>
            )}
            {items.length > 0 && filteredRows.length === 0 && (
              <TableRow>
                <TableCell colSpan={3}>
                  <Box component="span" color="text.secondary">
                    No lines match the current filter.
                  </Box>
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Stack>
  );
}
