import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Switch,
  TextField,
  Typography,
} from '@mui/material';
import { saveBackupTarget, type BackupTarget } from '@/api/bffBackups';
import type { SavedDisplay } from '@/storage/displays';
import { loadSession } from '@/storage/sessions';
import { completeDialogSave } from '@/util/dialogSave';
import {
  defaultBackupSchedule,
  formatScheduleSummary,
  HOUR_OPTIONS,
  scheduleFromTarget,
  WEEKDAY_LABELS,
  type BackupSchedule,
} from '@/util/backupSchedule';

export function BackupScheduleDialog({
  display,
  target,
  open,
  onClose,
  onSaved,
}: {
  display: SavedDisplay;
  target: BackupTarget | null;
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const session = loadSession(display.id);
  const [schedule, setSchedule] = useState<BackupSchedule>(() =>
    target ? scheduleFromTarget(target.schedule) : defaultBackupSchedule(),
  );
  const [retention, setRetention] = useState(target?.retentionCount ?? 3);
  const [enabled, setEnabled] = useState(target?.enabled ?? true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setSchedule(target ? scheduleFromTarget(target.schedule) : defaultBackupSchedule());
    setRetention(target?.retentionCount ?? 3);
    setEnabled(target?.enabled ?? true);
    setError(null);
  }, [open, target]);

  const summary = useMemo(() => formatScheduleSummary(schedule), [schedule]);
  const showWeeklyFields = schedule.frequency === 'weekly';

  const save = async () => {
    if (!session?.apiKey) return;
    setSaving(true);
    setError(null);
    try {
      await saveBackupTarget({
        displayId: display.id,
        label: display.label,
        baseUrl: display.baseUrl,
        apiKey: session.apiKey,
        schedule,
        retentionCount: retention,
        enabled,
      });
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      setError(String(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onClose={() => !saving && onClose()} maxWidth="sm" fullWidth>
      <DialogTitle>Configure backup — {display.label}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {error && <Alert severity="error">{error}</Alert>}
          <Typography variant="caption" sx={{
            color: "text.secondary"
          }}>
            {summary} (controller local time)
          </Typography>
          <FormControl size="small" fullWidth>
            <InputLabel id={`freq-dialog-${display.id}`}>Frequency</InputLabel>
            <Select
              labelId={`freq-dialog-${display.id}`}
              label="Frequency"
              value={schedule.frequency}
              disabled={saving}
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
            <InputLabel id={`interval-dialog-${display.id}`}>Repeat</InputLabel>
            <Select
              labelId={`interval-dialog-${display.id}`}
              label="Repeat"
              value={String(schedule.interval)}
              disabled={saving}
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
              <InputLabel id={`dow-dialog-${display.id}`}>Day of week</InputLabel>
              <Select
                labelId={`dow-dialog-${display.id}`}
                label="Day of week"
                value={String(schedule.dayOfWeek ?? 0)}
                disabled={saving}
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
              <InputLabel id={`hour-dialog-${display.id}`}>Hour</InputLabel>
              <Select
                labelId={`hour-dialog-${display.id}`}
                label="Hour"
                value={String(schedule.hour)}
                disabled={saving}
                onChange={(e) =>
                  setSchedule((s) => ({ ...s, hour: Number.parseInt(e.target.value, 10) }))
                }
              >
                {HOUR_OPTIONS.map((h) => (
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
              disabled={saving}
              value={schedule.minute}
              onChange={(e) =>
                setSchedule((s) => ({
                  ...s,
                  minute: Math.max(0, Math.min(59, Number(e.target.value) || 0)),
                }))
              }
              sx={{ width: 100 }}
              slotProps={{
                htmlInput: { min: 0, max: 59 }
              }}
            />
          </Stack>
          <TextField
            label="Retention count"
            type="number"
            size="small"
            fullWidth
            disabled={saving}
            value={retention}
            onChange={(e) => setRetention(Number(e.target.value) || 1)}
            slotProps={{
              htmlInput: { min: 1, max: 100 }
            }}
          />
          <FormControlLabel
            control={
              <Switch checked={enabled} onChange={(_, v) => setEnabled(v)} disabled={saving} />
            }
            label="Scheduled pulls"
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={saving}>
          Cancel
        </Button>
        <Button variant="contained" disabled={saving || !session?.apiKey} onClick={() => void save()}>
          {saving ? 'Saving…' : 'Save schedule'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
