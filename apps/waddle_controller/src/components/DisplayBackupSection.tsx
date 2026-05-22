import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  Paper,
  Stack,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
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
import { BackupScheduleDialog } from '@/components/BackupScheduleDialog';
import { DataViewEmptyState } from '@/components/dataView/DataViewEmptyState';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useClientDataView } from '@/hooks/useClientDataView';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { completeDialogSave } from '@/util/dialogSave';
import { useConfirmDialog } from '@/hooks/useConfirmDialog';
import { useDisplaysReachability } from '@/util/useDisplaysReachability';
import { loadSession } from '@/storage/sessions';
import {
  BACKUP_SCHEDULE_SORT_OPTIONS,
  backupScheduleSearchMatches,
  buildBackupScheduleRows,
  type BackupScheduleRow,
} from '@/util/backupScheduleRows';
import { pullDisplayBackupNow, saveDisplayBackupTarget } from '@/util/backupTargetSave';
import { scheduleFromTarget } from '@/util/backupSchedule';

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

function StatusChips({ row }: { row: BackupScheduleRow }) {
  const session = loadSession(row.display.id);
  return (
    <>
      {row.reachability?.state === 'online' && (
        <Chip label="Online" size="small" color="success" />
      )}
      {row.reachability?.state === 'offline' && (
        <Chip label="Offline" size="small" color="default" />
      )}
      {!session?.apiKey && <Chip label="Not adopted" size="small" color="warning" />}
    </>
  );
}

function ScheduleRowActions({
  row,
  busy,
  onBusyChange,
  onConfigure,
  onChanged,
  onRemove,
}: {
  row: BackupScheduleRow;
  busy: boolean;
  onBusyChange: (displayId: string | null) => void;
  onConfigure: () => void;
  onChanged: () => void;
  onRemove: () => void;
}) {
  const session = loadSession(row.display.id);
  const canManage = Boolean(session?.apiKey && session.role === 'admin');

  const setEnabled = async (enabled: boolean) => {
    if (!session?.apiKey) return;
    onBusyChange(row.display.id);
    try {
      await saveDisplayBackupTarget(row.display, session.apiKey, {
        enabled,
        existingTarget: row.target,
        schedule: row.target ? scheduleFromTarget(row.target.schedule) : undefined,
      });
      onChanged();
    } finally {
      onBusyChange(null);
    }
  };

  const pullNow = async () => {
    if (!session?.apiKey) return;
    onBusyChange(row.display.id);
    try {
      await pullDisplayBackupNow(row.display, session.apiKey, row.target);
      onChanged();
    } finally {
      onBusyChange(null);
    }
  };

  return (
    <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
      <FormControlLabel
        control={
          <Switch
            size="small"
            checked={row.enabled}
            disabled={!canManage || busy}
            onChange={(_, v) => void setEnabled(v)}
          />
        }
        label="Scheduled pulls"
      />
      <Button size="small" variant="outlined" disabled={!canManage || busy} onClick={onConfigure}>
        Configure
      </Button>
      <Button
        size="small"
        variant="outlined"
        disabled={!canManage || busy}
        onClick={() => void pullNow()}
      >
        Pull now
      </Button>
      {row.target && (
        <Button
          size="small"
          color="error"
          disabled={!canManage || busy}
          onClick={() => void onRemove()}
        >
          Remove
        </Button>
      )}
    </Stack>
  );
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
  const [configureDisplayId, setConfigureDisplayId] = useState<string | null>(null);
  const [rowBusyId, setRowBusyId] = useState<string | null>(null);
  const [reloadBusy, setReloadBusy] = useState(false);

  const { layout, setLayout } = useListLayoutPreference('controller-backup-schedules');
  const { reachability } = useDisplaysReachability(displays);

  const reload = useCallback(async () => {
    setError(null);
    setReloadBusy(true);
    try {
      const [t, r] = await Promise.all([
        listBackupTargets().catch(() => [] as BackupTarget[]),
        fetchLatestWaddleViewRelease().catch(() => null),
      ]);
      setTargets(t);
      setRelease(r);
    } catch (e) {
      setError(String(e));
    } finally {
      setReloadBusy(false);
    }
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  const targetByDisplayId = useMemo(() => {
    const m = new Map<string, BackupTarget>();
    for (const t of targets) {
      m.set(t.displayId, t);
    }
    return m;
  }, [targets]);

  const scheduleRows = useMemo(
    () => buildBackupScheduleRows(displays, targetByDisplayId, reachability),
    [displays, targetByDisplayId, reachability],
  );

  const dataView = useClientDataView({
    items: scheduleRows,
    sortOptions: BACKUP_SCHEDULE_SORT_OPTIONS,
    defaultSortId: 'label_asc',
    searchMatches: backupScheduleSearchMatches,
  });

  const displayRows = dataView.paginated.items;

  useEffect(() => {
    if (!focusDisplayId) return;
    const el = document.getElementById(`backup-schedule-${focusDisplayId}`);
    el?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }, [focusDisplayId, targets, displayRows.length]);

  const configureRow = configureDisplayId
    ? scheduleRows.find((r) => r.display.id === configureDisplayId)
    : null;

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

  const removeSchedule = async (row: BackupScheduleRow) => {
    if (!row.target) return;
    const ok = await confirm({
      title: 'Remove backup schedule?',
      message: `Remove backup schedule and stored snapshots for ${row.display.label}?`,
      confirmLabel: 'Remove',
      severity: 'warning',
    });
    if (!ok) return;
    await deleteBackupTarget(row.target.id);
    await reload();
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
          Configure automatic pulls per display in controller local time. New displays receive
          staggered run times (5 minutes apart). Archives are stored on the controller disk (not in
          SQLite). One-time download and restore live under{' '}
          <strong>Display settings → Backup &amp; restore</strong> for each display.
        </Typography>
      </Box>

      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <DataViewToolbar
        layout={layout}
        onLayoutChange={setLayout}
        search={dataView.search}
        onSearchChange={dataView.setSearch}
        searchPlaceholder="Search schedules…"
        sortOptions={BACKUP_SCHEDULE_SORT_OPTIONS}
        sortId={dataView.sortId}
        onSortChange={dataView.setSortId}
        onReload={() => void reload()}
        reloadDisabled={reloadBusy}
        reloadAriaLabel="Reload backup schedules"
      />

      <Stack spacing={2}>
        <DataViewEmptyState
          hasItems={scheduleRows.length > 0}
          hasFilteredMatches={displayRows.length > 0}
          emptyMessage="No displays to configure."
          noMatchesMessage="No schedules match your search."
        />
        {displayRows.length > 0 && layout === 'card' ? (
          <Box sx={catalogCardGridSx}>
            {displayRows.map((row) => (
              <Card
                key={row.display.id}
                id={`backup-schedule-${row.display.id}`}
                variant="outlined"
                sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}
              >
                <CardContent sx={{ flexGrow: 1 }}>
                  <Stack spacing={1.5}>
                    <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
                      <Typography variant="subtitle1" fontWeight={600}>
                        {row.display.label}
                      </Typography>
                      <StatusChips row={row} />
                    </Stack>
                    <Typography variant="body2" color="text.secondary">
                      {row.scheduleSummary}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      Last run: {row.lastRunLabel}
                    </Typography>
                  </Stack>
                </CardContent>
                <CardActions sx={{ px: 2, pb: 2, flexDirection: 'column', alignItems: 'stretch' }}>
                  <ScheduleRowActions
                    row={row}
                    busy={rowBusyId === row.display.id}
                    onBusyChange={setRowBusyId}
                    onConfigure={() => setConfigureDisplayId(row.display.id)}
                    onChanged={() => void reload()}
                    onRemove={() => void removeSchedule(row)}
                  />
                </CardActions>
              </Card>
            ))}
          </Box>
        ) : displayRows.length > 0 ? (
          <TableContainer component={Paper} variant="outlined">
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Display</TableCell>
                  <TableCell>Schedule</TableCell>
                  <TableCell>Last run</TableCell>
                  <TableCell>Scheduled pulls</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {displayRows.map((row) => {
                  const session = loadSession(row.display.id);
                  const canManage = Boolean(session?.apiKey && session.role === 'admin');
                  return (
                    <TableRow key={row.display.id} id={`backup-schedule-${row.display.id}`}>
                      <TableCell>
                        <Stack direction="row" spacing={0.5} alignItems="center" flexWrap="wrap" useFlexGap>
                          <Typography variant="body2" fontWeight={600}>
                            {row.display.label}
                          </Typography>
                          <StatusChips row={row} />
                        </Stack>
                      </TableCell>
                      <TableCell>{row.scheduleSummary}</TableCell>
                      <TableCell sx={{ maxWidth: 220 }}>{row.lastRunLabel}</TableCell>
                      <TableCell>
                        <Switch
                          size="small"
                          checked={row.enabled}
                          disabled={!canManage || rowBusyId === row.display.id}
                          onChange={(_, v) => {
                            if (!session?.apiKey) return;
                            setRowBusyId(row.display.id);
                            void saveDisplayBackupTarget(row.display, session.apiKey, {
                              enabled: v,
                              existingTarget: row.target,
                              schedule: row.target
                                ? scheduleFromTarget(row.target.schedule)
                                : undefined,
                            })
                              .then(() => reload())
                              .finally(() => setRowBusyId(null));
                          }}
                        />
                      </TableCell>
                      <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                        <Button
                          size="small"
                          disabled={!canManage || rowBusyId === row.display.id}
                          onClick={() => setConfigureDisplayId(row.display.id)}
                        >
                          Configure
                        </Button>
                        <Button
                          size="small"
                          disabled={!canManage || rowBusyId === row.display.id}
                          onClick={() => {
                            if (!session?.apiKey) return;
                            setRowBusyId(row.display.id);
                            void pullDisplayBackupNow(row.display, session.apiKey, row.target)
                              .then(() => reload())
                              .finally(() => setRowBusyId(null));
                          }}
                        >
                          Pull now
                        </Button>
                        {row.target && (
                          <Button
                            size="small"
                            color="error"
                            disabled={!canManage || rowBusyId === row.display.id}
                            onClick={() => void removeSchedule(row)}
                          >
                            Remove
                          </Button>
                        )}
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

      {configureRow && (
        <BackupScheduleDialog
          display={configureRow.display}
          target={configureRow.target}
          open={configureDisplayId != null}
          onClose={() => setConfigureDisplayId(null)}
          onSaved={() => void reload()}
        />
      )}

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
