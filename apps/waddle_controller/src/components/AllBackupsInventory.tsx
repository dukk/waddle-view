import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import {
  backupSnapshotDownloadUrl,
  deleteBackupSnapshot,
  listAllBackupSnapshots,
  restoreBackupSnapshot,
  type BackupSnapshot,
} from '@/api/bffBackups';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { useClientDataView } from '@/hooks/useClientDataView';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { completeDialogSave } from '@/util/dialogSave';
import type { SortOption } from '@/util/clientListPipeline';

const SNAPSHOT_SORT: SortOption<BackupSnapshot>[] = [
  {
    id: 'date',
    label: 'Date',
    compare: (a, b) => b.createdAt.localeCompare(a.createdAt),
  },
  {
    id: 'display',
    label: 'Display',
    compare: (a, b) => a.displayLabel.localeCompare(b.displayLabel),
  },
  {
    id: 'size',
    label: 'Size',
    compare: (a, b) => b.byteSize - a.byteSize,
  },
  {
    id: 'name',
    label: 'Name',
    compare: (a, b) => a.fileName.localeCompare(b.fileName),
  },
];

function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}

export function AllBackupsInventory({
  displayFilterId,
  onChanged,
}: {
  displayFilterId?: string | null;
  onChanged?: () => void;
}) {
  const [snapshots, setSnapshots] = useState<BackupSnapshot[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [restoreSnap, setRestoreSnap] = useState<BackupSnapshot | null>(null);

  const reload = useCallback(async () => {
    setError(null);
    try {
      const all = await listAllBackupSnapshots();
      setSnapshots(
        displayFilterId ? all.filter((s) => s.displayId === displayFilterId) : all,
      );
    } catch (e) {
      setError(String(e));
    }
  }, [displayFilterId]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const { layout, setLayout } = useListLayoutPreference('controller-all-backups');
  const dataView = useClientDataView({
    items: snapshots,
    sortOptions: SNAPSHOT_SORT,
    defaultSortId: 'date',
    searchMatches: (s, q) =>
      `${s.displayLabel} ${s.fileName} ${s.source} ${s.createdAt}`.toLowerCase().includes(q),
  });

  const runRestore = async () => {
    if (!restoreSnap) return;
    setBusy(true);
    setError(null);
    try {
      await restoreBackupSnapshot(restoreSnap.id);
      await completeDialogSave(async () => {
        onChanged?.();
        await reload();
      }, () => setRestoreSnap(null));
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Box component="section">
      <Typography variant="subtitle1" fontWeight={600} gutterBottom>
        Stored backups
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Archives kept on the controller filesystem. Restore pushes a copy to the display and
        restarts it.
      </Typography>
      {error && (
        <Alert severity="error" sx={{ mb: 1 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}
      <DataViewToolbar
        layout={layout}
        onLayoutChange={setLayout}
        search={dataView.search}
        onSearchChange={dataView.setSearch}
        sortOptions={SNAPSHOT_SORT.map((o) => ({ id: o.id, label: o.label }))}
        sortId={dataView.sortId}
        onSortChange={dataView.setSortId}
        onReload={() => void reload()}
      />
      {dataView.filteredTotal === 0 ? (
        <Typography variant="body2" color="text.secondary">
          No backups stored yet. Save a schedule and pull, or upload from Display settings.
        </Typography>
      ) : (
        <TableContainer>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Display</TableCell>
                <TableCell>File</TableCell>
                <TableCell>Size</TableCell>
                <TableCell>Source</TableCell>
                <TableCell>Taken</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {dataView.paginated.items.map((s) => (
                <TableRow key={s.id}>
                  <TableCell>{s.displayLabel}</TableCell>
                  <TableCell>{s.fileName}</TableCell>
                  <TableCell>{formatBytes(s.byteSize)}</TableCell>
                  <TableCell>{s.source}</TableCell>
                  <TableCell>{new Date(s.createdAt).toLocaleString()}</TableCell>
                  <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                    <Button
                      size="small"
                      component="a"
                      href={backupSnapshotDownloadUrl(s.id)}
                      download
                    >
                      Download
                    </Button>
                    <Button
                      size="small"
                      color="warning"
                      disabled={busy}
                      onClick={() => setRestoreSnap(s)}
                    >
                      Restore
                    </Button>
                    <Button
                      size="small"
                      color="error"
                      disabled={busy}
                      onClick={async () => {
                        if (!window.confirm(`Delete backup ${s.fileName}?`)) return;
                        setBusy(true);
                        try {
                          await deleteBackupSnapshot(s.id);
                          onChanged?.();
                          await reload();
                        } catch (e) {
                          setError(String(e));
                        } finally {
                          setBusy(false);
                        }
                      }}
                    >
                      Delete
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Dialog
        open={restoreSnap != null}
        onClose={() => !busy && setRestoreSnap(null)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>Restore backup to display?</DialogTitle>
        <DialogContent>
          <Alert severity="warning" sx={{ mb: 2 }}>
            This overwrites the display database and media with the selected archive. The display
            process will restart. This cannot be undone.
          </Alert>
          {restoreSnap && (
            <Stack spacing={0.5}>
              <Typography variant="body2">
                Display: <strong>{restoreSnap.displayLabel}</strong>
              </Typography>
              <Typography variant="body2">
                File: <strong>{restoreSnap.fileName}</strong>
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Taken: {new Date(restoreSnap.createdAt).toLocaleString()}
              </Typography>
            </Stack>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setRestoreSnap(null)} disabled={busy}>
            Cancel
          </Button>
          <Button
            variant="contained"
            color="warning"
            disabled={busy}
            onClick={() => void runRestore()}
          >
            {busy ? 'Restoring…' : 'Restore to display'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
