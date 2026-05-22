import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { Link as RouterLink } from 'react-router';
import { useDisplay } from '@/context/DisplayContext';
import { loadSession } from '@/storage/sessions';
import { fetchDisplayHealth, type DisplayReachability } from '@/util/displayHealth';
import { fetchLatestWaddleViewRelease, type WaddleViewReleaseInfo } from '@/api/githubReleases';
import {
  deleteBackupSnapshot,
  deleteBackupTarget,
  listBackupSnapshots,
  listBackupTargets,
  pullBackupNow,
  restoreBackupSnapshot,
  saveBackupTarget,
  uploadBackupArchive,
  backupSnapshotDownloadUrl,
  type BackupSnapshot,
  type BackupTarget,
} from '@/api/bffBackups';
import {
  createDisplayBackupJob,
  downloadDisplayBackupJob,
  fetchDisplayBackupJob,
  restoreDisplayBackupFile,
} from '@/api/displayBackups';
import { fetchDisplayUpgradeJob, startDisplayUpgrade } from '@/api/displayUpgrade';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { useClientDataView } from '@/hooks/useClientDataView';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { completeDialogSave } from '@/util/dialogSave';
import type { SortOption } from '@/util/clientListPipeline';

const SNAPSHOT_SORT: SortOption<BackupSnapshot>[] = [
  { id: 'date', label: 'Date', compare: (a, b) => b.createdAt.localeCompare(a.createdAt) },
  { id: 'size', label: 'Size', compare: (a, b) => b.byteSize - a.byteSize },
  { id: 'name', label: 'Name', compare: (a, b) => a.fileName.localeCompare(b.fileName) },
];

function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}

function isUpdateAvailable(
  health: DisplayReachability | undefined,
  release: WaddleViewReleaseInfo | null,
): boolean {
  if (!release || health?.state !== 'online') return false;
  const build = health.health.build?.trim();
  const tag = release.tag_name.replace(/^v/i, '');
  if (build && release.tag_name) {
    return build !== release.tag_name.replace(/^v/, '') && build !== tag;
  }
  const ver = health.health.version?.trim();
  if (ver && tag) {
    return ver !== tag;
  }
  return false;
}

export function DisplayOpsPage() {
  const { active } = useDisplay();
  const session = active ? loadSession(active.id) : null;
  const [health, setHealth] = useState<DisplayReachability | undefined>();
  const [release, setRelease] = useState<WaddleViewReleaseInfo | null>(null);
  const [target, setTarget] = useState<BackupTarget | null>(null);
  const [snapshots, setSnapshots] = useState<BackupSnapshot[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [cronExpr, setCronExpr] = useState('0 2 * * *');
  const [timezone, setTimezone] = useState('UTC');
  const [retention, setRetention] = useState(3);
  const [enabled, setEnabled] = useState(true);
  const [busy, setBusy] = useState(false);
  const [restoreOpen, setRestoreOpen] = useState(false);
  const [restoreFile, setRestoreFile] = useState<File | null>(null);
  const [upgradeOpen, setUpgradeOpen] = useState(false);
  const [upgradeBusy, setUpgradeBusy] = useState(false);

  const reload = useCallback(async () => {
    if (!active || !session?.apiKey) return;
    setError(null);
    try {
      const [h, r, targets] = await Promise.all([
        fetchDisplayHealth(active),
        fetchLatestWaddleViewRelease().catch(() => null),
        listBackupTargets().catch(() => [] as BackupTarget[]),
      ]);
      setHealth(h);
      setRelease(r);
      const t = targets.find((x) => x.displayId === active.id) ?? null;
      setTarget(t);
      if (t) {
        setCronExpr(t.cronExpr);
        setTimezone(t.timezone);
        setRetention(t.retentionCount);
        setEnabled(t.enabled);
        const snaps = await listBackupSnapshots(t.id);
        setSnapshots(snaps);
      } else {
        setSnapshots([]);
      }
    } catch (e) {
      setError(String(e));
    }
  }, [active, session?.apiKey]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const { layout, setLayout } = useListLayoutPreference('display-ops-backups');
  const dataView = useClientDataView({
    items: snapshots,
    sortOptions: SNAPSHOT_SORT,
    defaultSortId: 'date',
    searchMatches: (s, q) =>
      `${s.fileName} ${s.source} ${s.createdAt}`.toLowerCase().includes(q),
  });

  const piUpgradeReady =
    health?.state === 'online' &&
    health.health.platform_arch === 'arm64' &&
    health.health.upgrade_capable === true &&
    release?.pi_asset != null;

  const saveSchedule = async () => {
    if (!active || !session?.apiKey) return;
    setBusy(true);
    setError(null);
    try {
      const t = await saveBackupTarget({
        displayId: active.id,
        label: active.label,
        baseUrl: active.baseUrl,
        apiKey: session.apiKey,
        cronExpr,
        timezone,
        retentionCount: retention,
        enabled,
      });
      setTarget(t);
      setMsg('Backup schedule saved on controller.');
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const pullNow = async () => {
    if (!target) {
      await saveSchedule();
    }
    const tid = target?.id;
    if (!tid) return;
    setBusy(true);
    setError(null);
    try {
      await pullBackupNow(tid);
      setMsg('Backup pulled from display and stored on controller.');
      await reload();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const downloadToBrowser = async () => {
    if (!active) return;
    setBusy(true);
    setError(null);
    try {
      const { job_id } = await createDisplayBackupJob(active);
      let status = 'pending';
      for (let i = 0; i < 60 && status !== 'ready' && status !== 'failed'; i++) {
        await new Promise((r) => setTimeout(r, 500));
        const job = await fetchDisplayBackupJob(active, job_id);
        status = job.status;
        if (status === 'failed') throw new Error(job.error ?? 'backup failed');
      }
      if (status !== 'ready') throw new Error('Timed out waiting for backup');
      const blob = await downloadDisplayBackupJob(active, job_id);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `waddle_backup_${active.id}.zip`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const doRestoreUpload = async () => {
    if (!active || !restoreFile) return;
    setBusy(true);
    setError(null);
    try {
      if (target) {
        await uploadBackupArchive(target.id, restoreFile);
        setMsg('Archive stored on controller. Use Restore on a snapshot to apply to the display.');
        await reload();
      } else {
        await restoreDisplayBackupFile(active, restoreFile);
        setMsg('Restore sent to display. The display process should restart.');
      }
      await completeDialogSave(async () => {}, () => setRestoreOpen(false));
      setRestoreFile(null);
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const runUpgrade = async () => {
    if (!active || !release?.pi_asset) return;
    setUpgradeBusy(true);
    setError(null);
    try {
      const { job_id } = await startDisplayUpgrade(active, release.pi_asset);
      for (let i = 0; i < 120; i++) {
        await new Promise((r) => setTimeout(r, 2000));
        const job = await fetchDisplayUpgradeJob(active, job_id);
        if (job.status === 'failed') {
          throw new Error(job.error ?? 'upgrade failed');
        }
        if (job.status === 'succeeded') {
          setMsg('Upgrade completed on display.');
          break;
        }
      }
      await completeDialogSave(async () => {}, () => setUpgradeOpen(false));
    } catch (e) {
      setError(String(e));
    } finally {
      setUpgradeBusy(false);
    }
  };

  const updateAvailable = useMemo(
    () => isUpdateAvailable(health, release),
    [health, release],
  );

  if (!active) {
    return (
      <Alert severity="info">
        Select a display first.{' '}
        <RouterLink to="/controller-settings">Go to Displays</RouterLink>
      </Alert>
    );
  }

  if (!session?.apiKey) {
    return (
      <Alert severity="warning">
        Adopt this display with an admin API key to use backup and upgrade tools.
      </Alert>
    );
  }

  return (
    <Stack spacing={3}>
      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          Backup & updates — {active.label}
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Pull compressed backups from the display, store them on the controller, restore from saved
          copies, and upgrade Pi installs when a new GitHub release is available.
        </Typography>
      </Box>

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

      <Box component="section">
        <Typography variant="subtitle1" fontWeight={600} gutterBottom>
          Version
        </Typography>
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap alignItems="center">
          {health?.state === 'online' && (
            <Chip
              label={`${health.health.version ?? '?'}${health.health.build ? `+${health.health.build}` : ''}`}
              size="small"
            />
          )}
          {health?.state === 'online' && health.health.platform_arch && (
            <Chip label={health.health.platform_arch} size="small" variant="outlined" />
          )}
          {release && (
            <Chip
              label={`Latest: ${release.tag_name}`}
              size="small"
              color={updateAvailable ? 'warning' : 'default'}
              component="a"
              href={release.html_url}
              target="_blank"
              rel="noopener noreferrer"
              clickable
            />
          )}
          {updateAvailable && <Chip label="Update available" color="warning" size="small" />}
        </Stack>
        {piUpgradeReady && updateAvailable && (
          <Button sx={{ mt: 2 }} variant="contained" onClick={() => setUpgradeOpen(true)}>
            Upgrade Pi display
          </Button>
        )}
        {updateAvailable && !piUpgradeReady && release && (
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
            Automated upgrade is available on Linux arm64 with the upgrade helper installed.{' '}
            <a href={release.html_url} target="_blank" rel="noopener noreferrer">
              Download the release
            </a>{' '}
            for other platforms.
          </Typography>
        )}
      </Box>

      <Box component="section">
        <Typography variant="subtitle1" fontWeight={600} gutterBottom>
          Backup schedule (controller)
        </Typography>
        <Stack spacing={2} maxWidth={480}>
          <TextField
            label="Cron (daily: minute hour * * *)"
            value={cronExpr}
            onChange={(e) => setCronExpr(e.target.value)}
            size="small"
            fullWidth
          />
          <TextField
            label="Timezone"
            value={timezone}
            onChange={(e) => setTimezone(e.target.value)}
            size="small"
            fullWidth
          />
          <TextField
            label="Retention count"
            type="number"
            inputProps={{ min: 1, max: 100 }}
            value={retention}
            onChange={(e) => setRetention(Number(e.target.value) || 1)}
            size="small"
            fullWidth
          />
          <FormControl size="small" fullWidth>
            <InputLabel id="sched-enabled">Scheduled pulls</InputLabel>
            <Select
              labelId="sched-enabled"
              label="Scheduled pulls"
              value={enabled ? '1' : '0'}
              onChange={(e) => setEnabled(e.target.value === '1')}
            >
              <MenuItem value="1">Enabled</MenuItem>
              <MenuItem value="0">Disabled</MenuItem>
            </Select>
          </FormControl>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Button variant="contained" disabled={busy} onClick={() => void saveSchedule()}>
              Save schedule
            </Button>
            <Button variant="outlined" disabled={busy || !target} onClick={() => void pullNow()}>
              Pull backup now
            </Button>
          </Stack>
          {target?.lastRunAt && (
            <Typography variant="caption" color="text.secondary">
              Last run: {target.lastRunAt} ({target.lastStatus ?? '—'})
              {target.lastError ? ` — ${target.lastError}` : ''}
            </Typography>
          )}
        </Stack>
      </Box>

      <Box component="section">
        <Typography variant="subtitle1" fontWeight={600} gutterBottom>
          Manual backup / restore
        </Typography>
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
          <Button variant="outlined" disabled={busy} onClick={() => void downloadToBrowser()}>
            Download backup from display
          </Button>
          <Button variant="outlined" disabled={busy} onClick={() => setRestoreOpen(true)}>
            Upload archive to restore
          </Button>
        </Stack>
      </Box>

      <Box component="section">
        <Typography variant="subtitle2" gutterBottom>
          Stored backups ({dataView.filteredTotal})
        </Typography>
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
        {dataView.paginated.items.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            No backups stored yet. Pull one or upload an archive.
          </Typography>
        ) : (
          <Stack spacing={1}>
            {dataView.paginated.items.map((s) => (
              <Stack
                key={s.id}
                direction="row"
                spacing={1}
                alignItems="center"
                flexWrap="wrap"
                useFlexGap
              >
                <Typography variant="body2" sx={{ flex: 1, minWidth: 200 }}>
                  {s.fileName} · {formatBytes(s.byteSize)} · {s.source} ·{' '}
                  {new Date(s.createdAt).toLocaleString()}
                </Typography>
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
                  onClick={async () => {
                    if (!window.confirm('Restore this backup to the display? This overwrites data.')) {
                      return;
                    }
                    setBusy(true);
                    try {
                      await restoreBackupSnapshot(s.id);
                      setMsg('Restore sent to display.');
                    } catch (e) {
                      setError(String(e));
                    } finally {
                      setBusy(false);
                    }
                  }}
                >
                  Restore to display
                </Button>
                <Button
                  size="small"
                  color="error"
                  disabled={busy}
                  onClick={async () => {
                    if (!window.confirm('Delete this stored backup?')) return;
                    await deleteBackupSnapshot(s.id);
                    await reload();
                  }}
                >
                  Delete
                </Button>
              </Stack>
            ))}
          </Stack>
        )}
      </Box>

      {target && (
        <Button color="error" disabled={busy} onClick={async () => {
          if (!window.confirm('Remove backup schedule and stored snapshots for this display?')) return;
          await deleteBackupTarget(target.id);
          setTarget(null);
          setSnapshots([]);
        }}>
          Remove controller backup target
        </Button>
      )}

      <Dialog open={restoreOpen} onClose={() => !busy && setRestoreOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Upload backup archive</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" paragraph>
            Upload a .zip or .tar.gz from waddlectl or a prior download. Restoring overwrites display
            data and restarts the display process.
          </Typography>
          <Button variant="outlined" component="label">
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
              {restoreFile.name} ({formatBytes(restoreFile.size)})
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
            onClick={() => void doRestoreUpload()}
          >
            {busy ? 'Uploading…' : 'Upload & restore'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={upgradeOpen} onClose={() => !upgradeBusy && setUpgradeOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Upgrade display (Pi)</DialogTitle>
        <DialogContent>
          <Typography variant="body2" paragraph>
            Installs {release?.tag_name} from GitHub. The display will stop briefly; bundle is backed
            up under /opt/waddle-view before replace.
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Recommended: pull a controller backup first.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setUpgradeOpen(false)} disabled={upgradeBusy}>
            Cancel
          </Button>
          <Button variant="contained" color="warning" disabled={upgradeBusy} onClick={() => void runUpgrade()}>
            {upgradeBusy ? 'Upgrading…' : 'Start upgrade'}
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
