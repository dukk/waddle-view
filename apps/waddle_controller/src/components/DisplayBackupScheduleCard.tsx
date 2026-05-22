import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Button,
  Card,
  CardContent,
  Chip,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import {
  pullBackupNow,
  saveBackupTarget,
  type BackupTarget,
} from '@/api/bffBackups';
import type { SavedDisplay } from '@/storage/displays';
import { loadSession } from '@/storage/sessions';
import type { DisplayReachability } from '@/util/displayHealth';
import {
  defaultBackupSchedule,
  formatScheduleSummary,
  scheduleFromTarget,
  WEEKDAY_LABELS,
  type BackupSchedule,
} from '@/util/backupSchedule';

export function DisplayBackupScheduleCard({
  display,
  target,
  reachability,
  onChanged,
}: {
  display: SavedDisplay;
  target: BackupTarget | null;
  reachability?: DisplayReachability;
  onChanged: () => void;
}) {
  const session = loadSession(display.id);
  const [schedule, setSchedule] = useState<BackupSchedule>(() =>
    target ? scheduleFromTarget(target.schedule) : defaultBackupSchedule(),
  );
  const [timezone, setTimezone] = useState(
    () => target?.timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC',
  );
  const [retention, setRetention] = useState(target?.retentionCount ?? 3);
  const [enabled, setEnabled] = useState(target?.enabled ?? true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  useEffect(() => {
    if (target) {
      setSchedule(scheduleFromTarget(target.schedule));
      setTimezone(target.timezone);
      setRetention(target.retentionCount);
      setEnabled(target.enabled);
    }
  }, [target]);

  const summary = useMemo(() => formatScheduleSummary(schedule, timezone), [schedule, timezone]);

  const save = async () => {
    if (!session?.apiKey) return;
    setBusy(true);
    setError(null);
    try {
      await saveBackupTarget({
        displayId: display.id,
        label: display.label,
        baseUrl: display.baseUrl,
        apiKey: session.apiKey,
        schedule,
        timezone,
        retentionCount: retention,
        enabled,
      });
      setMsg('Schedule saved.');
      onChanged();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const pullNow = async () => {
    if (!session?.apiKey) return;
    setBusy(true);
    setError(null);
    try {
      let tid = target?.id;
      if (!tid) {
        const t = await saveBackupTarget({
          displayId: display.id,
          label: display.label,
          baseUrl: display.baseUrl,
          apiKey: session.apiKey,
          schedule,
          timezone,
          retentionCount: retention,
          enabled,
        });
        tid = t.id;
      }
      await pullBackupNow(tid);
      setMsg('Backup pulled and stored on controller.');
      onChanged();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const showWeeklyFields = schedule.frequency === 'weekly';

  return (
    <Card variant="outlined" id={`backup-display-${display.id}`}>
      <CardContent>
        <Stack spacing={2}>
          <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
            <Typography variant="subtitle1" fontWeight={600}>
              {display.label}
            </Typography>
            {reachability?.state === 'online' && (
              <Chip label="Online" size="small" color="success" />
            )}
            {reachability?.state === 'offline' && (
              <Chip label="Offline" size="small" color="default" />
            )}
            {!session?.apiKey && (
              <Chip label="Not adopted" size="small" color="warning" />
            )}
          </Stack>

          {!session?.apiKey ? (
            <Alert severity="info">Adopt with an admin API key to configure scheduled backups.</Alert>
          ) : session.role !== 'admin' ? (
            <Alert severity="warning">Scheduled backups require an admin adopted key.</Alert>
          ) : (
            <>
              {error && <Alert severity="error">{error}</Alert>}
              {msg && (
                <Alert severity="success" onClose={() => setMsg(null)}>
                  {msg}
                </Alert>
              )}
              <Typography variant="caption" color="text.secondary">
                {summary}
              </Typography>
              <Stack spacing={2} maxWidth={480}>
                <FormControl size="small" fullWidth>
                  <InputLabel id={`freq-${display.id}`}>Frequency</InputLabel>
                  <Select
                    labelId={`freq-${display.id}`}
                    label="Frequency"
                    value={schedule.frequency}
                    onChange={(e) => {
                      const frequency = e.target.value as 'daily' | 'weekly';
                      setSchedule((s) => ({
                        ...s,
                        frequency,
                        dayOfWeek: frequency === 'weekly' ? (s.dayOfWeek ?? 0) : null,
                      }));
                    }}
                  >
                    <MenuItem value="daily">Every day</MenuItem>
                    <MenuItem value="weekly">Every week</MenuItem>
                  </Select>
                </FormControl>
                <FormControl size="small" fullWidth>
                  <InputLabel id={`interval-${display.id}`}>Repeat</InputLabel>
                  <Select
                    labelId={`interval-${display.id}`}
                    label="Repeat"
                    value={String(schedule.interval)}
                    onChange={(e) =>
                      setSchedule((s) => ({
                        ...s,
                        interval: e.target.value === '2' ? 2 : 1,
                      }))
                    }
                  >
                    <MenuItem value="1">
                      {schedule.frequency === 'weekly' ? 'Every week' : 'Every day'}
                    </MenuItem>
                    <MenuItem value="2">
                      {schedule.frequency === 'weekly' ? 'Every 2 weeks' : 'Every 2 days'}
                    </MenuItem>
                  </Select>
                </FormControl>
                {showWeeklyFields && (
                  <FormControl size="small" fullWidth>
                    <InputLabel id={`dow-${display.id}`}>Day of week</InputLabel>
                    <Select
                      labelId={`dow-${display.id}`}
                      label="Day of week"
                      value={String(schedule.dayOfWeek ?? 0)}
                      onChange={(e) =>
                        setSchedule((s) => ({
                          ...s,
                          dayOfWeek: Number.parseInt(e.target.value, 10),
                        }))
                      }
                    >
                      {WEEKDAY_LABELS.map((label, i) => (
                        <MenuItem key={label} value={String(i)}>
                          {label}
                        </MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                )}
                <Stack direction="row" spacing={1}>
                  <FormControl size="small" sx={{ minWidth: 100 }}>
                    <InputLabel id={`hour-${display.id}`}>Hour</InputLabel>
                    <Select
                      labelId={`hour-${display.id}`}
                      label="Hour"
                      value={String(schedule.hour)}
                      onChange={(e) =>
                        setSchedule((s) => ({ ...s, hour: Number.parseInt(e.target.value, 10) }))
                      }
                    >
                      {[0, 1, 2, 3, 4, 5].map((h) => (
                        <MenuItem key={h} value={String(h)}>
                          {String(h).padStart(2, '0')}:00
                        </MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                  <TextField
                    label="Minute"
                    type="number"
                    size="small"
                    inputProps={{ min: 0, max: 59 }}
                    value={schedule.minute}
                    onChange={(e) =>
                      setSchedule((s) => ({
                        ...s,
                        minute: Math.max(0, Math.min(59, Number(e.target.value) || 0)),
                      }))
                    }
                    sx={{ width: 100 }}
                  />
                </Stack>
                <Typography variant="caption" color="text.secondary">
                  Night window (00:00–05:59) in the display timezone.
                </Typography>
                <TextField
                  label="Timezone"
                  size="small"
                  fullWidth
                  value={timezone}
                  onChange={(e) => setTimezone(e.target.value)}
                />
                <TextField
                  label="Retention count"
                  type="number"
                  size="small"
                  fullWidth
                  inputProps={{ min: 1, max: 100 }}
                  value={retention}
                  onChange={(e) => setRetention(Number(e.target.value) || 1)}
                />
                <FormControl size="small" fullWidth>
                  <InputLabel id={`enabled-${display.id}`}>Scheduled pulls</InputLabel>
                  <Select
                    labelId={`enabled-${display.id}`}
                    label="Scheduled pulls"
                    value={enabled ? '1' : '0'}
                    onChange={(e) => setEnabled(e.target.value === '1')}
                  >
                    <MenuItem value="1">Enabled</MenuItem>
                    <MenuItem value="0">Disabled</MenuItem>
                  </Select>
                </FormControl>
                <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                  <Button variant="contained" disabled={busy} onClick={() => void save()}>
                    {busy ? 'Saving…' : 'Save schedule'}
                  </Button>
                  <Button variant="outlined" disabled={busy} onClick={() => void pullNow()}>
                    Pull backup now
                  </Button>
                </Stack>
                {target?.lastRunAt && (
                  <Typography variant="caption" color="text.secondary">
                    Last run: {new Date(target.lastRunAt).toLocaleString()} ({target.lastStatus ?? '—'})
                    {target.lastError ? ` — ${target.lastError}` : ''}
                  </Typography>
                )}
              </Stack>
            </>
          )}
        </Stack>
      </CardContent>
    </Card>
  );
}
