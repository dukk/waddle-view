import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Card,
  CardContent,
  Chip,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import ExtensionIcon from '@mui/icons-material/Extension';
import { useDisplay } from '@/context/DisplayContext';
import { apiJson, ApiError } from '@/api/client';
import { DataViewEmptyState } from '@/components/dataView/DataViewEmptyState';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useClientDataView } from '@/hooks/useClientDataView';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import {
  buildColumnSortOptions,
  columnSortToolbarOptions,
  compareLocale,
  tieBreakLocale,
  type ColumnSortField,
} from '@/util/dataViewColumnSort';

type PluginRow = {
  id: string;
  version: string;
  path: string;
  capabilities: string[];
};

const PLUGIN_SORT_FIELDS: ColumnSortField<PluginRow>[] = [
  {
    id: 'version',
    label: 'Version',
    compare: (a, b) =>
      tieBreakLocale(compareLocale(a.version, b.version), a.id, b.id),
  },
  {
    id: 'path',
    label: 'Path',
    compare: (a, b) => tieBreakLocale(compareLocale(a.path, b.path), a.id, b.id),
  },
  {
    id: 'capabilities',
    label: 'Capabilities',
    compare: (a, b) =>
      tieBreakLocale(
        compareLocale(a.capabilities.join(', '), b.capabilities.join(', ')),
        a.id,
        b.id,
      ),
  },
];

const PLUGIN_SORT_OPTIONS = buildColumnSortOptions(PLUGIN_SORT_FIELDS);
const PLUGIN_SORT_TOOLBAR = columnSortToolbarOptions(PLUGIN_SORT_FIELDS);

function PluginTable({ rows }: { rows: PluginRow[] }) {
  return (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>ID</TableCell>
            <TableCell>Version</TableCell>
            <TableCell>Path</TableCell>
            <TableCell>Capabilities</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((p) => (
            <TableRow key={p.id} hover>
              <TableCell sx={{ fontWeight: 600 }}>{p.id}</TableCell>
              <TableCell>{p.version}</TableCell>
              <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.85rem', wordBreak: 'break-all' }}>
                {p.path}
              </TableCell>
              <TableCell>
                <Stack direction="row" spacing={0.5} useFlexGap sx={{
                  flexWrap: "wrap"
                }}>
                  {p.capabilities.map((c) => (
                    <Chip key={c} size="small" label={c} />
                  ))}
                </Stack>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

function PluginCard({ row }: { row: PluginRow }) {
  return (
    <Card variant="outlined" sx={{ height: '100%' }}>
      <CardContent>
        <Typography variant="h6">{row.id}</Typography>
        <Typography variant="body2" sx={{
          color: "text.secondary"
        }}>
          v{row.version} — {row.path}
        </Typography>
        <Stack
          direction="row"
          spacing={1}
          sx={{
            flexWrap: "wrap",
            mt: 1
          }}>
          {row.capabilities.map((c) => (
            <Chip key={c} size="small" label={c} />
          ))}
        </Stack>
      </CardContent>
    </Card>
  );
}

export function PluginsPage() {
  const { active } = useDisplay();
  const { layout, setLayout } = useListLayoutPreference('plugins');
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [items, setItems] = useState<PluginRow[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const data = await apiJson<{ items: PluginRow[] }>(active, '/v1/plugins');
        setItems(data.items ?? []);
      } catch (e) {
        setError(e instanceof ApiError ? e.message : String(e));
      }
    });
  }, [active, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load]);

  const dataView = useClientDataView({
    items,
    sortOptions: PLUGIN_SORT_OPTIONS,
    defaultSortId: 'version',
    useSortOrder: true,
    searchMatches: (row, q) =>
      row.id.toLowerCase().includes(q) ||
      row.version.toLowerCase().includes(q) ||
      row.path.toLowerCase().includes(q) ||
      row.capabilities.some((c) => c.toLowerCase().includes(q)),
  });

  const displayRows = dataView.paginated.items;

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={3}>
      <DisplayRefreshIndicator loading={loading} />
      <Box>
        <Stack
          direction="row"
          spacing={1}
          sx={{
            alignItems: "center",
            mb: 0.5
          }}>
          <ExtensionIcon color="action" />
          <Typography variant="h6" sx={{
            fontWeight: 600
          }}>
            Plugins
          </Typography>
        </Stack>
        <Typography variant="body2" sx={{
          color: "text.secondary"
        }}>
          Extensions loaded on the active display (see WADDLE_DISPLAY_PLUGINS_DIR).
        </Typography>
      </Box>
      {error ? (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      ) : null}
      <DataViewToolbar
        layout={layout}
        onLayoutChange={setLayout}
        search={dataView.search}
        onSearchChange={dataView.setSearch}
        searchPlaceholder="Search plugins…"
        sortOptions={PLUGIN_SORT_TOOLBAR}
        sortId={dataView.sortId}
        onSortChange={dataView.setSortId}
        order={dataView.order}
        onOrderChange={dataView.setOrder}
        onReload={() => void load()}
        reloadDisabled={loading}
        reloadAriaLabel="Reload plugins"
      />
      <Stack spacing={2}>
        <DataViewEmptyState
          hasItems={items.length > 0}
          hasFilteredMatches={displayRows.length > 0}
          emptyMessage="No plugins loaded. Set WADDLE_DISPLAY_PLUGINS_DIR and restart the display."
        />
        {displayRows.length > 0 && layout === 'card' ? (
          <Box sx={catalogCardGridSx}>
            {displayRows.map((p) => (
              <PluginCard key={p.id} row={p} />
            ))}
          </Box>
        ) : displayRows.length > 0 ? (
          <PluginTable rows={displayRows} />
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
