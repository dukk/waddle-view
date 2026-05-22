import { useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  Typography,
} from '@mui/material';
import { Link as RouterLink } from 'react-router';
import type { SavedDisplay } from '@/storage/displays';
import { loadSession } from '@/storage/sessions';
import {
  downloadDisplayBackupToBrowser,
  restoreDisplayBackupFromFile,
} from '@/util/displayBackupActions';
import { completeDialogSave } from '@/util/dialogSave';

export function DisplayBackupTabContent({ display }: { display: SavedDisplay }) {
  const session = loadSession(display.id);
  const isAdmin = session?.role === 'admin';
  const [error, setError] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [restoreOpen, setRestoreOpen] = useState(false);
  const [restoreFile, setRestoreFile] = useState<File | null>(null);
  const [confirmRestoreOpen, setConfirmRestoreOpen] = useState(false);

  if (!session?.apiKey) {
    return (
      <Alert severity="warning">
        Adopt this display with an admin API key on the Displays tab to download or restore backups.
      </Alert>
    );
  }

  if (!isAdmin) {
    return (
      <Alert severity="warning">
        Backup and restore require an adopted <strong>admin</strong> API key (display maintenance
        permission).
      </Alert>
    );
  }

  const runDownload = async () => {
    setBusy(true);
    setError(null);
    try {
      await downloadDisplayBackupToBrowser(display);
      setMsg('Backup downloaded.');
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const runRestore = async () => {
    if (!restoreFile) return;
    setBusy(true);
    setError(null);
    try {
      await restoreDisplayBackupFromFile(display, restoreFile);
      setMsg('Restore sent to display. The display process should restart.');
      await completeDialogSave(async () => {}, () => {
        setRestoreOpen(false);
        setConfirmRestoreOpen(false);
        setRestoreFile(null);
      });
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Download a one-time backup archive from this display or upload a prior archive to restore.
        Scheduled backups run on the controller.
      </Typography>

      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}
      {msg && (
        <Alert severity="success" onClose={() => setMsg(null)}>
          {msg}
        </Alert>
      )}

      <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
        <Button variant="contained" disabled={busy} onClick={() => void runDownload()}>
          {busy ? 'Working…' : 'Download backup'}
        </Button>
        <Button variant="outlined" color="warning" disabled={busy} onClick={() => setRestoreOpen(true)}>
          Upload restore file
        </Button>
      </Stack>

      <Box>
        <Typography variant="body2" color="text.secondary">
          To schedule automatic pulls and manage stored copies, use{' '}
          <RouterLink
            to={`/controller-settings?tab=backup&display=${encodeURIComponent(display.id)}`}
          >
            Controller settings → Backup &amp; restore
          </RouterLink>
          .
        </Typography>
      </Box>

      <Dialog open={restoreOpen} onClose={() => !busy && setRestoreOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Upload restore file</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" paragraph>
            Choose a .zip or .tar.gz backup archive. Restoring overwrites the display database and
            media blobs, then restarts the display process.
          </Typography>
          <Button variant="outlined" component="label" disabled={busy}>
            Choose file
            <input
              type="file"
              accept=".zip,.tar.gz,.tgz,application/zip,application/gzip"
              hidden
              onChange={(e) => setRestoreFile(e.target.files?.[0] ?? null)}
            />
          </Button>
          {restoreFile && (
            <Typography variant="body2" sx={{ mt: 1 }}>
              {restoreFile.name}
            </Typography>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setRestoreOpen(false)} disabled={busy}>
            Cancel
          </Button>
          <Button
            variant="contained"
            color="warning"
            disabled={busy || !restoreFile}
            onClick={() => {
              setRestoreOpen(false);
              setConfirmRestoreOpen(true);
            }}
          >
            Continue
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={confirmRestoreOpen}
        onClose={() => !busy && setConfirmRestoreOpen(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>Confirm restore</DialogTitle>
        <DialogContent>
          <Alert severity="warning" sx={{ mb: 2 }}>
            This will overwrite all display data with the uploaded archive. This action cannot be
            undone.
          </Alert>
          {restoreFile && (
            <Typography variant="body2">
              File: <strong>{restoreFile.name}</strong>
            </Typography>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmRestoreOpen(false)} disabled={busy}>
            Cancel
          </Button>
          <Button
            variant="contained"
            color="warning"
            disabled={busy || !restoreFile}
            onClick={() => void runRestore()}
          >
            {busy ? 'Restoring…' : 'Restore display'}
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
