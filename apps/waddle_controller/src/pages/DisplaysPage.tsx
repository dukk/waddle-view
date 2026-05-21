import { useCallback, useEffect, useState } from 'react';

import {
  Alert,
  Box,
  Button,
  Card,
  CardActions,
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
  Tooltip,
  Typography,
} from '@mui/material';
import { DataViewEmptyState } from '@/components/dataView/DataViewEmptyState';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useClientDataView } from '@/hooks/useClientDataView';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import type { SortOption } from '@/util/clientListPipeline';
import type { DisplaysReachabilityMap } from '@/util/useDisplaysReachability';

import { AdoptDisplayDialog } from '@/components/AdoptDisplayDialog';

import { EditDisplayDialog } from '@/components/EditDisplayDialog';

import { DisplaysBackupSection } from '@/components/DisplaysBackupSection';
import { DisplaysRecoverySection } from '@/components/DisplaysRecoverySection';

import { useDisplay } from '@/context/DisplayContext';

import type { SavedDisplay } from '@/storage/displays';

import { loadSession } from '@/storage/sessions';

import { hasAnyAdoptedDisplay } from '@/util/adoptedDisplays';
import { formatDisplayHostSummary } from '@/util/displayHealth';
import { useDisplaysReachability } from '@/util/useDisplaysReachability';



const DISPLAY_SORT_OPTIONS: SortOption<SavedDisplay>[] = [
  { id: 'label_asc', label: 'Name (A–Z)', compare: (a, b) => a.label.localeCompare(b.label) },
  { id: 'label_desc', label: 'Name (Z–A)', compare: (a, b) => b.label.localeCompare(a.label) },
  { id: 'url_asc', label: 'URL (A–Z)', compare: (a, b) => a.baseUrl.localeCompare(b.baseUrl) },
];

type DisplaysPageProps = {

  /** When true, omit outer page chrome (used inside Controller Settings tabs). */

  embedded?: boolean;

};



function DisplayStatusBlock({
  status,
}: {
  status: DisplaysReachabilityMap[string];
}) {
  const hostSummary =
    status?.state === 'online' ? formatDisplayHostSummary(status.health) : null;

  return (
    <Stack spacing={0.5} useFlexGap>
      <Stack direction="row" alignItems="center" spacing={0.75} useFlexGap flexWrap="wrap">
        {status?.state === 'checking' && (
          <Chip label="Checking…" size="small" variant="outlined" />
        )}
        {status?.state === 'online' && (
          <Chip label="Online" size="small" color="success" variant="outlined" />
        )}
        {status?.state === 'offline' && (
          <Tooltip title={status.message}>
            <Chip label="Offline" size="small" color="error" variant="outlined" />
          </Tooltip>
        )}
      </Stack>
      {hostSummary && (
        <Tooltip title={hostSummary}>
          <Typography
            variant="caption"
            color="text.secondary"
            sx={{
              display: 'block',
              maxWidth: 320,
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            {hostSummary}
          </Typography>
        </Tooltip>
      )}
      {status?.state === 'offline' && (
        <Box sx={{ maxWidth: 320 }}>
          <Typography variant="caption" color="error">
            {status.message}
          </Typography>
        </Box>
      )}
    </Stack>
  );
}

function DisplayCard({
  display,
  isActive,
  status,
  session,
  onEdit,
  onRemove,
}: {
  display: SavedDisplay;
  isActive: boolean;
  status: DisplaysReachabilityMap[string];
  session: ReturnType<typeof loadSession>;
  onEdit: () => void;
  onRemove: () => void;
}) {
  return (
    <Card variant="outlined" sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1.5}>
          <Stack direction="row" alignItems="center" spacing={1} useFlexGap flexWrap="wrap">
            <Typography variant="subtitle1" fontWeight={isActive ? 600 : 500}>
              {display.label}
            </Typography>
            {isActive && <Chip label="Active" size="small" color="primary" />}
          </Stack>
          <DisplayStatusBlock status={status} />
          <Typography variant="body2" sx={{ fontFamily: 'monospace', wordBreak: 'break-all' }}>
            {display.baseUrl}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {session ? (
              <>
                {session.identifier} ({session.role})
              </>
            ) : (
              'Not adopted'
            )}
          </Typography>
        </Stack>
      </CardContent>
      <CardActions sx={{ justifyContent: 'flex-end', px: 2, pb: 2 }}>
        <Button size="small" variant="outlined" onClick={onEdit}>
          Edit
        </Button>
        <Button size="small" variant="outlined" color="error" onClick={onRemove}>
          Remove
        </Button>
      </CardActions>
    </Card>
  );
}

export function DisplaysPage({ embedded = false }: DisplaysPageProps) {
  const { layout, setLayout } = useListLayoutPreference('displays');
  const { displays, active, refresh, removeDisplay, updateDisplay } = useDisplay();

  const [success, setSuccess] = useState<string | null>(null);

  const [labelError, setLabelError] = useState<string | null>(null);

  const [adoptOpen, setAdoptOpen] = useState(false);

  const [editDisplay, setEditDisplay] = useState<SavedDisplay | null>(null);

  const adopted = hasAnyAdoptedDisplay(displays);
  const { reachability, refreshing: reachabilityRefreshing, refreshReachability } =
    useDisplaysReachability(displays);

  const dataView = useClientDataView({
    items: displays,
    sortOptions: DISPLAY_SORT_OPTIONS,
    defaultSortId: 'label_asc',
    searchMatches: (d, q) =>
      d.id.toLowerCase().includes(q) ||
      d.label.toLowerCase().includes(q) ||
      d.baseUrl.toLowerCase().includes(q),
  });

  const displayRows = dataView.paginated.items;

  const handleReload = useCallback(() => {
    refresh();
    void refreshReachability();
  }, [refresh, refreshReachability]);

  const toolbar = (
    <DataViewToolbar
      layout={layout}
      onLayoutChange={setLayout}
      search={dataView.search}
      onSearchChange={dataView.setSearch}
      searchPlaceholder="Search displays…"
      sortOptions={DISPLAY_SORT_OPTIONS}
      sortId={dataView.sortId}
      onSortChange={dataView.setSortId}
      onReload={handleReload}
      reloadDisabled={reachabilityRefreshing}
      reloadAriaLabel="Reload displays"
    >
      <Button variant="contained" onClick={() => setAdoptOpen(true)}>
        Adopt display
      </Button>
    </DataViewToolbar>
  );



  useEffect(() => {

    if (!adopted) {

      setAdoptOpen(true);

    }

  }, [adopted]);



  const handleAdopted = () => {

    refresh();

    setSuccess('Display adopted and saved.');

    setAdoptOpen(false);

  };



  return (
    <Stack spacing={2}>
      <DisplayRefreshIndicator loading={reachabilityRefreshing} />

      {!embedded && (
        <Stack spacing={1.5}>
          <Typography variant="body2" color="text.secondary">
            Pair displays with this browser, rename them, and switch which display the controller
            targets. Adopted API keys stay in local storage only—they are not included in backup
            export.
          </Typography>
          {toolbar}
        </Stack>
      )}

      {embedded && toolbar}



      {success && (

        <Alert severity="success" onClose={() => setSuccess(null)}>

          {success}

        </Alert>

      )}

      {labelError && (

        <Alert severity="error" onClose={() => setLabelError(null)}>

          {labelError}

        </Alert>

      )}



      <Stack spacing={2}>
        <DataViewEmptyState
          hasItems={displays.length > 0}
          hasFilteredMatches={displayRows.length > 0}
          emptyMessage="No displays saved yet. Use Adopt display to pair with a display."
        />
        {displayRows.length > 0 && layout === 'card' ? (
        <Box sx={catalogCardGridSx}>
          {displayRows.map((d) => {
            const session = loadSession(d.id);
            const isActive = active?.id === d.id;
            const status = reachability[d.id] ?? { state: 'checking' as const };
            return (
              <DisplayCard
                key={d.id}
                display={d}
                isActive={isActive}
                status={status}
                session={session}
                onEdit={() => setEditDisplay(d)}
                onRemove={() => removeDisplay(d.id)}
              />
            );
          })}
        </Box>
      ) : displayRows.length > 0 ? (
        <TableContainer component={Paper} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Display</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Base URL</TableCell>
                <TableCell>Adoption</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {displayRows.map((d) => {
                const session = loadSession(d.id);
                const isActive = active?.id === d.id;
                const status = reachability[d.id] ?? { state: 'checking' as const };
                return (
                  <TableRow key={d.id} selected={isActive}>
                    <TableCell>
                      <Stack direction="row" alignItems="center" spacing={1} useFlexGap flexWrap="wrap">
                        <Typography variant="body2" fontWeight={isActive ? 600 : 400}>
                          {d.label}
                        </Typography>
                        {isActive && <Chip label="Active" size="small" color="primary" />}
                      </Stack>
                    </TableCell>
                    <TableCell>
                      <DisplayStatusBlock status={status} />
                    </TableCell>
                    <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                      {d.baseUrl}
                    </TableCell>
                    <TableCell>
                      {session ? (
                        <Typography variant="body2">
                          {session.identifier} ({session.role})
                        </Typography>
                      ) : (
                        <Typography variant="body2" color="text.secondary">
                          Not adopted
                        </Typography>
                      )}
                    </TableCell>
                    <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                      <Button size="small" onClick={() => setEditDisplay(d)}>
                        Edit
                      </Button>
                      <Button size="small" color="error" onClick={() => removeDisplay(d.id)}>
                        Remove
                      </Button>
                    </TableCell>
                  </TableRow>
                );
              })}
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

      <DisplaysRecoverySection onChanged={refresh} />
      <DisplaysBackupSection onChanged={refresh} />



      {adoptOpen && (

        <AdoptDisplayDialog

          open

          dismissible={adopted}

          onClose={() => setAdoptOpen(false)}

          onAdopted={handleAdopted}

        />

      )}



      {editDisplay && (

        <EditDisplayDialog

          display={editDisplay}

          onClose={() => setEditDisplay(null)}

          onSave={async (input) => {
            setLabelError(null);
            try {
              await updateDisplay(editDisplay.id, input);
              setSuccess('Display saved.');
            } catch (e) {
              setLabelError(String(e));
              throw e;
            }
          }}

        />

      )}

    </Stack>

  );

}


