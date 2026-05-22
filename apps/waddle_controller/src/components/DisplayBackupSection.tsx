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
  Stack,
  Typography,
} from '@mui/material';
import { useSearchParams } from 'react-router';
import { useDisplay } from '@/context/DisplayContext';
import type { DisplayReachability } from '@/util/displayHealth';
import { fetchLatestWaddleViewRelease, type WaddleViewReleaseInfo } from '@/api/githubReleases';
import {
  deleteBackupTarget,
  listBackupTargets,
  type BackupTarget,
} from '@/api/bffBackups';
import { fetchDisplayUpgradeJob, startDisplayUpgrade } from '@/api/displayUpgrade';
import { AllBackupsInventory } from '@/components/AllBackupsInventory';
import { DisplayBackupScheduleCard } from '@/components/DisplayBackupScheduleCard';
import { completeDialogSave } from '@/util/dialogSave';
import { useConfirmDialog } from '@/hooks/useConfirmDialog';
import { useDisplaysReachability } from '@/util/useDisplaysReachability';

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

/** Scheduled backups and stored archive inventory (controller settings tab). */
export function DisplayBackupSection() {
  const { confirm, ConfirmDialogHost } = useConfirmDialog();
  const { displays } = useDisplay();
  const [searchParams] = useSearchParams();
  const focusDisplayId = searchParams.get('display');
  const [targets, setTargets] = useState<BackupTarget[]>([]);
  const [release, setRelease] = useState<WaddleViewReleaseInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [upgradeOpen, setUpgradeOpen] = useState(false);
  const [upgradeBusy, setUpgradeBusy] = useState(false);
  const [upgradeDisplayId, setUpgradeDisplayId] = useState<string | null>(null);

  const { reachability } = useDisplaysReachability(displays);

  const reload = useCallback(async () => {
    setError(null);
    try {
      const [t, r] = await Promise.all([
        listBackupTargets().catch(() => [] as BackupTarget[]),
        fetchLatestWaddleViewRelease().catch(() => null),
      ]);
      setTargets(t);
      setRelease(r);
    } catch (e) {
      setError(String(e));
    }
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  useEffect(() => {
    if (!focusDisplayId) return;
    const el = document.getElementById(`backup-display-${focusDisplayId}`);
    el?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }, [focusDisplayId, targets]);

  const targetByDisplayId = useMemo(() => {
    const m = new Map<string, BackupTarget>();
    for (const t of targets) {
      m.set(t.displayId, t);
    }
    return m;
  }, [targets]);

  const activeForUpgrade = displays.find((d) => d.id === upgradeDisplayId) ?? displays[0];
  const upgradeHealth = activeForUpgrade
    ? reachability[activeForUpgrade.id]
    : undefined;

  const piUpgradeReady =
    upgradeHealth?.state === 'online' &&
    upgradeHealth.health.platform_arch === 'arm64' &&
    upgradeHealth.health.upgrade_capable === true &&
    release?.pi_asset != null;

  const updateAvailable = isUpdateAvailable(upgradeHealth, release);

  const runUpgrade = async () => {
    if (!activeForUpgrade || !release?.pi_asset) return;
    setUpgradeBusy(true);
    setError(null);
    try {
      const { job_id } = await startDisplayUpgrade(activeForUpgrade, release.pi_asset);
      for (let i = 0; i < 120; i++) {
        await new Promise((r) => setTimeout(r, 2000));
        const job = await fetchDisplayUpgradeJob(activeForUpgrade, job_id);
        if (job.status === 'failed') {
          throw new Error(job.error ?? 'upgrade failed');
        }
        if (job.status === 'succeeded') {
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

  if (displays.length === 0) {
    return (
      <Alert severity="info">
        Add a display on the Displays tab first.
      </Alert>
    );
  }

  return (
    <Stack spacing={3}>
      <Box>
        <Typography variant="subtitle1" fontWeight={600} gutterBottom>
          Scheduled backups
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Configure automatic pulls per display. Archives are stored on the controller disk (not in
          SQLite). One-time download and restore live under{' '}
          <strong>Display settings → Backup &amp; restore</strong> for each display.
        </Typography>
      </Box>

      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <Stack spacing={2}>
        {displays.map((d) => (
          <DisplayBackupScheduleCard
            key={d.id}
            display={d}
            target={targetByDisplayId.get(d.id) ?? null}
            reachability={reachability[d.id]}
            onChanged={() => void reload()}
          />
        ))}
      </Stack>

      {release && (
        <Box component="section">
          <Typography variant="subtitle1" fontWeight={600} gutterBottom>
            Pi display upgrade
          </Typography>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap alignItems="center">
            <Chip label={`Latest: ${release.tag_name}`} size="small" />
            {updateAvailable && <Chip label="Update available" color="warning" size="small" />}
          </Stack>
          {piUpgradeReady && updateAvailable && (
            <Button
              sx={{ mt: 2 }}
              variant="contained"
              onClick={() => {
                setUpgradeDisplayId(activeForUpgrade?.id ?? null);
                setUpgradeOpen(true);
              }}
            >
              Upgrade Pi display
            </Button>
          )}
        </Box>
      )}

      <AllBackupsInventory
        displayFilterId={focusDisplayId}
        onChanged={() => void reload()}
      />

      {targets.length > 0 && (
        <Box>
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>
            Remove schedules
          </Typography>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            {targets.map((t) => (
              <Button
                key={t.id}
                size="small"
                color="error"
                onClick={async () => {
                  const ok = await confirm({
                    title: 'Remove backup schedule?',
                    message: `Remove backup schedule and stored snapshots for ${t.label}?`,
                    confirmLabel: 'Remove',
                    severity: 'warning',
                  });
                  if (!ok) {
                    return;
                  }
                  await deleteBackupTarget(t.id);
                  await reload();
                }}
              >
                Remove {t.label}
              </Button>
            ))}
          </Stack>
        </Box>
      )}

      <Dialog open={upgradeOpen} onClose={() => !upgradeBusy && setUpgradeOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Upgrade display (Pi)</DialogTitle>
        <DialogContent>
          <Typography variant="body2" paragraph>
            Installs {release?.tag_name} from GitHub on {activeForUpgrade?.label ?? 'display'}.
            The display will stop briefly.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setUpgradeOpen(false)} disabled={upgradeBusy}>
            Cancel
          </Button>
          <Button
            variant="contained"
            color="warning"
            disabled={upgradeBusy}
            onClick={() => void runUpgrade()}
          >
            {upgradeBusy ? 'Upgrading…' : 'Start upgrade'}
          </Button>
        </DialogActions>
      </Dialog>
      <ConfirmDialogHost />
    </Stack>
  );
}
