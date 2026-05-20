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
import { useDisplayFormat } from '@/context/DisplayFormatContext';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { integrationDisplayName } from '@/util/integrationDisplayName';

type Line = {
  at_ms: number;
  channel: string;
  message: string;
  integration_type?: string | null;
};

function integrationTypeLabel(type: string): string {
  return integrationDisplayName(type.trim());
}

function integrationCell(type: string | null | undefined): string {
  if (type == null || typeof type !== 'string' || !type.trim()) {
    return '—';
  }
  return integrationTypeLabel(type);
}

export function ActivityPage() {
  const { active } = useDisplay();
  const { formatDateTimeWithMs } = useDisplayFormat();
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [items, setItems] = useState<Line[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [filterText, setFilterText] = useState('');
  const [channelFilter, setChannelFilter] = useState<string>('');
  const [integrationTypeFilter, setIntegrationTypeFilter] = useState<string>('');

  const channels = useMemo(() => {
    const set = new Set<string>();
    for (const row of items) {
      if (row.channel) set.add(row.channel);
    }
    return [...set].sort((a, b) => a.localeCompare(b));
  }, [items]);

  const integrationTypes = useMemo(() => {
    const set = new Set<string>();
    for (const row of items) {
      const t = row.integration_type?.trim();
      if (t) set.add(t);
    }
    return [...set].sort((a, b) => a.localeCompare(b));
  }, [items]);

  const filteredRows = useMemo(() => {
    const newestFirst = [...items].reverse();
    const q = filterText.trim().toLowerCase();
    return newestFirst.filter((row) => {
      if (channelFilter && row.channel !== channelFilter) return false;
      const rowType = row.integration_type?.trim() ?? '';
      if (integrationTypeFilter && rowType !== integrationTypeFilter) return false;
      if (!q) return true;
      const d = new Date(row.at_ms);
      const timeStr = Number.isNaN(d.getTime())
        ? String(row.at_ms)
        : formatDateTimeWithMs(d).toLowerCase();
      const typeLabel = rowType ? integrationTypeLabel(rowType).toLowerCase() : '';
      return (
        row.message.toLowerCase().includes(q) ||
        row.channel.toLowerCase().includes(q) ||
        rowType.toLowerCase().includes(q) ||
        typeLabel.includes(q) ||
        String(row.at_ms).includes(q) ||
        timeStr.includes(q)
      );
    });
  }, [items, filterText, channelFilter, integrationTypeFilter, formatDateTimeWithMs]);

  useEffect(() => {
    if (channelFilter && !channels.includes(channelFilter)) {
      setChannelFilter('');
    }
  }, [channels, channelFilter]);

  useEffect(() => {
    if (integrationTypeFilter && !integrationTypes.includes(integrationTypeFilter)) {
      setIntegrationTypeFilter('');
    }
  }, [integrationTypes, integrationTypeFilter]);

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
        Filter by channel, integration type, or message text to trace collector errors, curation, and
        runtime events.
      </Typography>
      {error && <Alert severity="error">{error}</Alert>}
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }}>
        <TextField
          label="Filter"
          placeholder="Message, channel, integration type, time, or at_ms"
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
        <FormControl size="small" sx={{ minWidth: 200 }}>
          <InputLabel id="activity-integration-type-filter-label">Integration type</InputLabel>
          <Select
            labelId="activity-integration-type-filter-label"
            label="Integration type"
            value={integrationTypeFilter}
            onChange={(e) => setIntegrationTypeFilter(e.target.value)}
          >
            <MenuItem value="">
              <em>All</em>
            </MenuItem>
            {integrationTypes.map((t) => (
              <MenuItem key={t} value={t}>
                {integrationTypeLabel(t)}
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
              <TableCell width={160}>Integration</TableCell>
              <TableCell>Message</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredRows.map((row, i) => (
              <TableRow
                key={`${row.at_ms}-${row.channel}-${row.integration_type ?? ''}-${i}-${row.message.slice(0, 48)}`}
                title={String(row.at_ms)}
              >
                <TableCell sx={{ whiteSpace: 'nowrap' }}>
                  {Number.isNaN(new Date(row.at_ms).getTime())
                    ? String(row.at_ms)
                    : formatDateTimeWithMs(new Date(row.at_ms))}
                </TableCell>
                <TableCell>{row.channel}</TableCell>
                <TableCell
                  title={row.integration_type?.trim() || undefined}
                  sx={{ whiteSpace: 'nowrap' }}
                >
                  {integrationCell(row.integration_type)}
                </TableCell>
                <TableCell sx={{ fontFamily: 'monospace', fontSize: 12, whiteSpace: 'pre-wrap' }}>
                  {row.message}
                </TableCell>
              </TableRow>
            ))}
            {items.length === 0 && (
              <TableRow>
                <TableCell colSpan={4}>No telemetry lines yet.</TableCell>
              </TableRow>
            )}
            {items.length > 0 && filteredRows.length === 0 && (
              <TableRow>
                <TableCell colSpan={4}>
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
