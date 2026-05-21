import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Card,
  CardContent,
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
  Typography,
} from '@mui/material';
import { useDisplay } from '@/context/DisplayContext';
import { apiJson, ApiError } from '@/api/client';
import { DataViewEmptyState } from '@/components/dataView/DataViewEmptyState';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { useDisplayFormat } from '@/context/DisplayFormatContext';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { useClientDataView } from '@/hooks/useClientDataView';
import type { SortOption } from '@/util/clientListPipeline';
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

const ACTIVITY_SORT_OPTIONS: SortOption<Line>[] = [
  {
    id: 'newest',
    label: 'Newest first',
    compare: (a, b) => b.at_ms - a.at_ms,
  },
  {
    id: 'oldest',
    label: 'Oldest first',
    compare: (a, b) => a.at_ms - b.at_ms,
  },
  {
    id: 'channel',
    label: 'Channel',
    compare: (a, b) => a.channel.localeCompare(b.channel) || b.at_ms - a.at_ms,
  },
];

export function ActivityPage() {
  const { active } = useDisplay();
  const { formatDateTimeWithMs } = useDisplayFormat();
  const { layout, setLayout } = useListLayoutPreference('activity');
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [items, setItems] = useState<Line[]>([]);
  const [error, setError] = useState<string | null>(null);
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

  const channelFiltered = useMemo(() => {
    return items.filter((row) => {
      if (channelFilter && row.channel !== channelFilter) return false;
      const rowType = row.integration_type?.trim() ?? '';
      if (integrationTypeFilter && rowType !== integrationTypeFilter) return false;
      return true;
    });
  }, [items, channelFilter, integrationTypeFilter]);

  const dataView = useClientDataView({
    items: channelFiltered,
    sortOptions: ACTIVITY_SORT_OPTIONS,
    defaultSortId: 'newest',
    searchMatches: (row, q) => {
      const d = new Date(row.at_ms);
      const timeStr = Number.isNaN(d.getTime())
        ? String(row.at_ms)
        : formatDateTimeWithMs(d).toLowerCase();
      const typeLabel = row.integration_type?.trim()
        ? integrationTypeLabel(row.integration_type.trim()).toLowerCase()
        : '';
      return (
        row.message.toLowerCase().includes(q) ||
        row.channel.toLowerCase().includes(q) ||
        (row.integration_type?.trim() ?? '').toLowerCase().includes(q) ||
        typeLabel.includes(q) ||
        String(row.at_ms).includes(q) ||
        timeStr.includes(q)
      );
    },
  });

  const displayRows = dataView.paginated.items;

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

  const filterSlot = (
    <>
      <FormControl size="small" sx={{ minWidth: 180 }}>
        <InputLabel id="activity-channel-filter-label">Channel</InputLabel>
        <Select
          labelId="activity-channel-filter-label"
          label="Channel"
          value={channelFilter}
          onChange={(e) => {
            setChannelFilter(e.target.value);
            dataView.resetPage();
          }}
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
          onChange={(e) => {
            setIntegrationTypeFilter(e.target.value);
            dataView.resetPage();
          }}
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
    </>
  );

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

      <DataViewToolbar
        layout={layout}
        onLayoutChange={setLayout}
        search={dataView.search}
        onSearchChange={dataView.setSearch}
        searchPlaceholder="Search log lines…"
        sortOptions={ACTIVITY_SORT_OPTIONS}
        sortId={dataView.sortId}
        onSortChange={dataView.setSortId}
        onReload={() => void load()}
        reloadDisabled={loading}
        reloadAriaLabel="Reload activity log"
        filterSlot={filterSlot}
      />

      <Stack spacing={2}>
        <DataViewEmptyState
          hasItems={items.length > 0}
          hasFilteredMatches={displayRows.length > 0}
          emptyMessage="No telemetry lines yet."
        />
        {displayRows.length > 0 && layout === 'card' ? (
          <Stack spacing={1}>
            {displayRows.map((row, i) => (
              <Card key={`${row.at_ms}-${row.channel}-${i}`} variant="outlined">
                <CardContent sx={{ py: 1.5, '&:last-child': { pb: 1.5 } }}>
                  <Stack spacing={0.5}>
                    <Typography variant="caption" color="text.secondary">
                      {Number.isNaN(new Date(row.at_ms).getTime())
                        ? String(row.at_ms)
                        : formatDateTimeWithMs(new Date(row.at_ms))}{' '}
                      · {row.channel}
                      {row.integration_type?.trim()
                        ? ` · ${integrationCell(row.integration_type)}`
                        : ''}
                    </Typography>
                    <Typography
                      variant="body2"
                      sx={{ fontFamily: 'monospace', fontSize: 12, whiteSpace: 'pre-wrap' }}
                    >
                      {row.message}
                    </Typography>
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Stack>
        ) : displayRows.length > 0 ? (
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
                {displayRows.map((row, i) => (
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
              </TableBody>
            </Table>
          </TableContainer>
        ) : null}
        <DataViewPagination
          count={dataView.filteredTotal}
          page={dataView.paginated.page}
          pageSize={dataView.paginated.pageSize}
          onPageChange={dataView.setPage}
          onPageSizeChange={dataView.setPageSize}
        />
      </Stack>
    </Stack>
  );
}
