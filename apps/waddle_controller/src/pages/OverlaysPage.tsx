import { useCallback, useEffect, useMemo, useState } from 'react';
import AddIcon from '@mui/icons-material/Add';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import EditIcon from '@mui/icons-material/Edit';
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
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
  Divider,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Switch,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import RefreshIcon from '@mui/icons-material/Refresh';
import TodayOutlinedIcon from '@mui/icons-material/TodayOutlined';
import Form from '@rjsf/mui';
import validator from '@rjsf/validator-ajv8';
import type { RJSFSchema } from '@rjsf/utils';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { parseJsonObject } from '@/util/json';
import type { SavedDisplay } from '@/storage/displays';

/** Mirrors `GET /v1/display/overlays` item shape (`overlayScheduleToJson`). */
type OverlayScheduleRow = {
  id: string;
  enabled: boolean;
  overlay_type: string;
  label: string;
  config_json: unknown;
  config_json_schema?: unknown;
  repeat_annually: boolean;
  year_exact: number | null;
  start_month: number;
  start_day: number;
  end_month: number | null;
  end_day: number | null;
  nth_week_of_month: number | null;
  nth_weekday: number | null;
};

const BUILTIN_OVERLAY_TYPES = [
  'hearts_rain',
  'birthday_confetti',
  'bouncing_message',
] as const;

const MONTH_NAMES = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
] as const;

/** Dart `DateTime.weekday`: Monday = 1 … Sunday = 7 */
const DART_WEEKDAY_NAMES = [
  '',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
] as const;

const OVERLAY_TYPE_LABELS: Record<string, string> = {
  hearts_rain: 'Hearts rain',
  birthday_confetti: 'Birthday confetti',
  bouncing_message: 'Bouncing message',
};

function readBool(v: unknown, defaultValue: boolean): boolean {
  if (typeof v === 'boolean') return v;
  if (v === 1 || v === '1') return true;
  if (v === 0 || v === '0') return false;
  if (typeof v === 'string') {
    const t = v.trim().toLowerCase();
    if (t === 'true' || t === 'yes' || t === 'on') return true;
    if (t === 'false' || t === 'no' || t === 'off') return false;
  }
  return defaultValue;
}

function readInt(v: unknown, fallback: number): number {
  if (typeof v === 'number' && Number.isFinite(v)) return Math.trunc(v);
  if (typeof v === 'string' && v.trim() !== '') {
    const n = Number.parseInt(v, 10);
    if (Number.isFinite(n)) return n;
  }
  return fallback;
}

function readNullableInt(v: unknown): number | null {
  if (v == null) return null;
  if (typeof v === 'number' && Number.isFinite(v)) return Math.trunc(v);
  if (typeof v === 'string' && v.trim() !== '') {
    const n = Number.parseInt(v, 10);
    if (Number.isFinite(n)) return n;
  }
  return null;
}

function parseOverlayRow(raw: Record<string, unknown>): OverlayScheduleRow | null {
  const id = raw.id;
  if (typeof id !== 'string' || !id.trim()) return null;
  return {
    id: id.trim(),
    enabled: readBool(raw.enabled, true),
    overlay_type:
      typeof raw.overlay_type === 'string'
        ? raw.overlay_type
        : typeof raw.overlay_kind === 'string'
          ? raw.overlay_kind
          : '',
    label: typeof raw.label === 'string' ? raw.label : '',
    config_json: raw.config_json,
    config_json_schema: raw.config_json_schema,
    repeat_annually: readBool(raw.repeat_annually, true),
    year_exact: readNullableInt(raw.year_exact),
    start_month: readInt(raw.start_month, 1),
    start_day: readInt(raw.start_day, 1),
    end_month: readNullableInt(raw.end_month),
    end_day: readNullableInt(raw.end_day),
    nth_week_of_month: readNullableInt(raw.nth_week_of_month),
    nth_weekday: readNullableInt(raw.nth_weekday),
  };
}

function decodeMessagesFromConfig(configJson: unknown): string[] {
  const cfg = parseJsonObject(configJson);
  const raw = cfg.messages;
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const e of raw) {
    if (typeof e === 'string' && e.trim()) out.push(e.trim());
  }
  return out;
}

/** JS `Date.getDay()` → Dart `DateTime.weekday` (Mon=1 … Sun=7). */
function dartWeekdayFromJs(d: Date): number {
  const js = d.getDay();
  return js === 0 ? 7 : js;
}

/**
 * Same calendar logic as `nthWeekdayOccurrenceInMonth` in
 * `apps/waddle_display/lib/display/overlay/celebration_overlay_schedule.dart`.
 */
function nthWeekdayOccurrenceInMonth(
  year: number,
  month: number,
  nthWeekInMonth: number,
  weekday: number,
): Date | null {
  if (nthWeekInMonth < 1 || nthWeekInMonth > 5) return null;
  if (weekday < 1 || weekday > 7) return null;
  if (month < 1 || month > 12) return null;

  const first = new Date(year, month - 1, 1);
  let delta = weekday - dartWeekdayFromJs(first);
  if (delta < 0) delta += 7;
  const firstOccurrenceDay = 1 + delta;
  const targetDay = firstOccurrenceDay + (nthWeekInMonth - 1) * 7;
  const lastDayOfMonth = new Date(year, month, 0).getDate();
  if (targetDay > lastDayOfMonth) return null;
  return new Date(year, month - 1, targetDay);
}

function calendarDate(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function datesEqual(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

function safeDate(y: number, month: number, day: number): Date | null {
  const dt = new Date(y, month - 1, day);
  if (dt.getFullYear() !== y || dt.getMonth() !== month - 1 || dt.getDate() !== day) {
    return null;
  }
  return dt;
}

/** Mirrors `matchesCelebrationOverlay` in `celebration_overlay_schedule.dart` (local calendar). */
function matchesOverlaySchedule(row: OverlayScheduleRow, localNow: Date): boolean {
  if (!row.enabled) return false;
  const today = calendarDate(localNow);

  if (row.nth_week_of_month != null) {
    if (row.nth_weekday == null) return false;
    const y = row.repeat_annually ? today.getFullYear() : row.year_exact;
    if (y == null) return false;
    if (!row.repeat_annually && row.year_exact !== today.getFullYear()) return false;

    const anchor = nthWeekdayOccurrenceInMonth(
      y,
      row.start_month,
      row.nth_week_of_month,
      row.nth_weekday,
    );
    if (anchor == null) return false;
    return datesEqual(anchor, today);
  }

  const y = row.repeat_annually ? today.getFullYear() : row.year_exact;
  if (y == null) return false;
  if (!row.repeat_annually && row.year_exact !== today.getFullYear()) return false;

  const rangeStart = safeDate(y, row.start_month, row.start_day);
  if (!rangeStart) return false;
  const endM = row.end_month ?? row.start_month;
  const endD = row.end_day ?? row.start_day;
  const rangeEnd = safeDate(y, endM, endD);
  if (!rangeEnd) return false;
  if (rangeStart > rangeEnd) return false;
  return today >= rangeStart && today <= rangeEnd;
}

function ordinal(n: number): string {
  const mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return `${n}th`;
  switch (n % 10) {
    case 1:
      return `${n}st`;
    case 2:
      return `${n}nd`;
    case 3:
      return `${n}rd`;
    default:
      return `${n}th`;
  }
}

function formatMd(month: number, day: number): string {
  if (month < 1 || month > 12) return `${month}/${day}`;
  return `${MONTH_NAMES[month - 1]} ${day}`;
}

function yearScopePhrase(row: OverlayScheduleRow): string {
  if (row.repeat_annually) return 'repeats every year';
  if (row.year_exact != null) return `only in ${row.year_exact}`;
  return 'one-time (year not set)';
}

function scheduleSummary(row: OverlayScheduleRow): string {
  const scope = yearScopePhrase(row);

  if (row.nth_week_of_month != null && row.nth_weekday != null) {
    const wn = DART_WEEKDAY_NAMES[row.nth_weekday] ?? `weekday ${row.nth_weekday}`;
    const month = MONTH_NAMES[Math.max(0, Math.min(11, row.start_month - 1))] ?? 'month';
    return `${ordinal(row.nth_week_of_month)} ${wn} in ${month} — ${scope}`;
  }

  const endM = row.end_month ?? row.start_month;
  const endD = row.end_day ?? row.start_day;
  const sameDay = endM === row.start_month && endD === row.start_day;
  const window = sameDay
    ? formatMd(row.start_month, row.start_day)
    : `${formatMd(row.start_month, row.start_day)} → ${formatMd(endM, endD)}`;
  return `${window} — ${scope}`;
}

function scheduleKindLabel(row: OverlayScheduleRow): string {
  if (row.nth_week_of_month != null) return 'Nth weekday';
  return 'Date range';
}

function overlayTypeLabel(type: string): string {
  const k = type.trim();
  return OVERLAY_TYPE_LABELS[k] ?? (k || 'Unknown type');
}

function sortSchedules(rows: OverlayScheduleRow[], now: Date): OverlayScheduleRow[] {
  return [...rows].sort((a, b) => {
    const at = matchesOverlaySchedule(a, now) ? 0 : 1;
    const bt = matchesOverlaySchedule(b, now) ? 0 : 1;
    if (at !== bt) return at - bt;
    const ak = a.start_month * 40 + a.start_day;
    const bk = b.start_month * 40 + b.start_day;
    if (ak !== bk) return ak - bk;
    return a.id.localeCompare(b.id);
  });
}

function isBuiltinOverlayType(t: string): boolean {
  return (BUILTIN_OVERLAY_TYPES as readonly string[]).includes(t.trim());
}

const permissiveOverlayConfigSchema: RJSFSchema = {
  type: 'object',
  additionalProperties: true,
};

function overlayRowConfigSchema(schemaField: unknown): RJSFSchema {
  if (schemaField != null && typeof schemaField === 'object' && !Array.isArray(schemaField)) {
    return schemaField as RJSFSchema;
  }
  if (typeof schemaField === 'string' && schemaField.trim()) {
    try {
      const parsed: unknown = JSON.parse(schemaField);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as RJSFSchema;
      }
    } catch {
      /* fall through */
    }
  }
  return permissiveOverlayConfigSchema;
}

function defaultConfigForOverlayType(t: string): Record<string, unknown> {
  const ty = t.trim();
  if (ty === 'hearts_rain') return { messages: [] as string[] };
  if (ty === 'birthday_confetti') {
    return {
      messages: ['Happy birthday!'] as string[],
      shapes: ['mix'] as string[],
      density: 0.36,
    };
  }
  if (ty === 'bouncing_message') {
    return {
      messages: ['Hello'] as string[],
      font_size: 38,
      shadow: true,
      speed: 1.0,
    };
  }
  return { messages: [] as string[] };
}

type OverlayDialogMode = 'create' | 'edit';

function OverlayScheduleDialog({
  open,
  mode,
  active,
  initial,
  allRows,
  onClose,
  onSaved,
}: {
  open: boolean;
  mode: OverlayDialogMode;
  active: SavedDisplay;
  initial: OverlayScheduleRow | null;
  allRows: OverlayScheduleRow[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [saving, setSaving] = useState(false);
  const [localErr, setLocalErr] = useState<string | null>(null);
  const [id, setId] = useState('');
  const [label, setLabel] = useState('');
  const [overlayType, setOverlayType] = useState('hearts_rain');
  const [enabled, setEnabled] = useState(true);
  const [repeatAnnually, setRepeatAnnually] = useState(true);
  const [yearExact, setYearExact] = useState('');
  const [startMonth, setStartMonth] = useState('1');
  const [startDay, setStartDay] = useState('1');
  const [endMonth, setEndMonth] = useState('');
  const [endDay, setEndDay] = useState('');
  const [nthWeekOfMonth, setNthWeekOfMonth] = useState('');
  const [nthWeekday, setNthWeekday] = useState('');
  const [configForm, setConfigForm] = useState<Record<string, unknown>>({});

  useEffect(() => {
    if (!open) return;
    setLocalErr(null);
    if (initial) {
      setId(initial.id);
      setLabel(initial.label);
      setOverlayType(initial.overlay_type);
      setEnabled(initial.enabled);
      setRepeatAnnually(initial.repeat_annually);
      setYearExact(initial.year_exact == null ? '' : String(initial.year_exact));
      setStartMonth(String(initial.start_month));
      setStartDay(String(initial.start_day));
      setEndMonth(initial.end_month == null ? '' : String(initial.end_month));
      setEndDay(initial.end_day == null ? '' : String(initial.end_day));
      setNthWeekOfMonth(
        initial.nth_week_of_month == null ? '' : String(initial.nth_week_of_month),
      );
      setNthWeekday(initial.nth_weekday == null ? '' : String(initial.nth_weekday));
      setConfigForm(parseJsonObject(initial.config_json));
    } else {
      setId('');
      setLabel('');
      setOverlayType('hearts_rain');
      setEnabled(true);
      setRepeatAnnually(true);
      setYearExact('');
      setStartMonth('1');
      setStartDay('1');
      setEndMonth('');
      setEndDay('');
      setNthWeekOfMonth('');
      setNthWeekday('');
      setConfigForm(defaultConfigForOverlayType('hearts_rain'));
    }
  }, [open, initial]);

  const configSchema = useMemo(() => {
    const hit = allRows.find((r) => r.overlay_type.trim() === overlayType.trim());
    if (hit?.config_json_schema != null) {
      return overlayRowConfigSchema(hit.config_json_schema);
    }
    return permissiveOverlayConfigSchema;
  }, [allRows, overlayType]);

  const handleOverlayTypeSelect = (next: string) => {
    setOverlayType(next);
    if (mode === 'create') {
      setConfigForm(defaultConfigForOverlayType(next));
    }
  };

  const submit = async () => {
    setLocalErr(null);
    const idTrim = id.trim();
    if (!idTrim) {
      setLocalErr('Id is required (slug: letters, digits, dot, hyphen).');
      return;
    }
    if (!/^[a-z0-9][a-z0-9_.-]*$/i.test(idTrim)) {
      setLocalErr('Id must match slug pattern ^[a-z0-9][a-z0-9_.-]*$');
      return;
    }
    const sm = Number(startMonth);
    const sd = Number(startDay);
    if (!Number.isFinite(sm) || !Number.isFinite(sd)) {
      setLocalErr('Start month and start day must be numbers.');
      return;
    }
    const ye = yearExact.trim() === '' ? null : Number(yearExact);
    if (!repeatAnnually && (ye == null || !Number.isFinite(ye))) {
      setLocalErr('When not repeating annually, set a calendar year (year_exact).');
      return;
    }
    const em = endMonth.trim() === '' ? null : Number(endMonth);
    const ed = endDay.trim() === '' ? null : Number(endDay);
    const nwm = nthWeekOfMonth.trim() === '' ? null : Number(nthWeekOfMonth);
    const nwd = nthWeekday.trim() === '' ? null : Number(nthWeekday);

    const body: Record<string, unknown> = {
      enabled,
      overlay_type: overlayType.trim(),
      label,
      config_json: configForm,
      repeat_annually: repeatAnnually,
      year_exact: repeatAnnually ? null : ye,
      start_month: sm,
      start_day: sd,
      end_month: em,
      end_day: ed,
      nth_week_of_month: nwm,
      nth_weekday: nwd,
    };

    setSaving(true);
    try {
      if (mode === 'create') {
        await apiFetch(active, '/v1/display/overlays', {
          method: 'POST',
          body: JSON.stringify({ id: idTrim, ...body }),
        });
      } else {
        await apiFetch(active, `/v1/display/overlays/${encodeURIComponent(idTrim)}`, {
          method: 'PATCH',
          body: JSON.stringify(body),
        });
      }
      onSaved();
      onClose();
    } catch (e) {
      setLocalErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle>{mode === 'create' ? 'New overlay schedule' : 'Edit overlay schedule'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {localErr && <Alert severity="error">{localErr}</Alert>}
          <TextField
            label="Id"
            value={id}
            onChange={(e) => setId(e.target.value)}
            disabled={mode === 'edit'}
            required
            helperText="Stable slug (cannot change after create)."
          />
          <TextField label="Label" value={label} onChange={(e) => setLabel(e.target.value)} />
          <FormControl fullWidth>
            <InputLabel id="overlay-type-label">Overlay type</InputLabel>
            <Select
              labelId="overlay-type-label"
              label="Overlay type"
              value={isBuiltinOverlayType(overlayType) ? overlayType : '__custom__'}
              onChange={(e) => {
                const v = String(e.target.value);
                if (v === '__custom__') {
                  setOverlayType('');
                } else {
                  handleOverlayTypeSelect(v);
                }
              }}
            >
              {BUILTIN_OVERLAY_TYPES.map((t) => (
                <MenuItem key={t} value={t}>
                  {overlayTypeLabel(t)}
                </MenuItem>
              ))}
              <MenuItem value="__custom__">Custom…</MenuItem>
            </Select>
          </FormControl>
          {(!isBuiltinOverlayType(overlayType) || overlayType.trim() === '') && (
            <TextField
              label="Custom overlay_type"
              value={overlayType}
              onChange={(e) => setOverlayType(e.target.value)}
              helperText="Any slug; the display only renders built-in types today."
            />
          )}
          <Stack direction="row" alignItems="center" spacing={1}>
            <Switch checked={enabled} onChange={(_, v) => setEnabled(v)} />
            <Typography>Enabled</Typography>
          </Stack>
          <Stack direction="row" alignItems="center" spacing={1}>
            <Switch checked={repeatAnnually} onChange={(_, v) => setRepeatAnnually(v)} />
            <Typography>Repeat annually</Typography>
          </Stack>
          {!repeatAnnually && (
            <TextField
              label="year_exact"
              value={yearExact}
              onChange={(e) => setYearExact(e.target.value)}
              type="number"
              helperText="Required when not repeating annually."
            />
          )}
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
            <TextField
              label="start_month"
              value={startMonth}
              onChange={(e) => setStartMonth(e.target.value)}
              type="number"
            />
            <TextField
              label="start_day"
              value={startDay}
              onChange={(e) => setStartDay(e.target.value)}
              type="number"
            />
          </Stack>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
            <TextField
              label="end_month (optional)"
              value={endMonth}
              onChange={(e) => setEndMonth(e.target.value)}
              type="number"
            />
            <TextField
              label="end_day (optional)"
              value={endDay}
              onChange={(e) => setEndDay(e.target.value)}
              type="number"
            />
          </Stack>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
            <TextField
              label="nth_week_of_month (optional)"
              value={nthWeekOfMonth}
              onChange={(e) => setNthWeekOfMonth(e.target.value)}
              type="number"
              helperText="1–5; use with nth_weekday (Mon=1 … Sun=7)."
            />
            <TextField
              label="nth_weekday (optional)"
              value={nthWeekday}
              onChange={(e) => setNthWeekday(e.target.value)}
              type="number"
            />
          </Stack>
          <Typography variant="subtitle2">config_json</Typography>
          <Typography variant="caption" color="text.secondary">
            Phrases live in <code>messages</code> (array of strings). Schema below comes from an
            existing row of the same overlay_type when available; otherwise permissive JSON.
          </Typography>
          <Box sx={{ '& .MuiFormControl-root': { mb: 1 } }}>
            <Form
              schema={configSchema}
              formData={configForm}
              validator={validator}
              onChange={(e) => setConfigForm(e.formData as Record<string, unknown>)}
              liveValidate
            >
              <Box sx={{ display: 'none' }}>
                <button type="submit" />
              </Box>
            </Form>
          </Box>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={saving}>
          Cancel
        </Button>
        <Button variant="contained" onClick={() => void submit()} disabled={saving}>
          Save
        </Button>
      </DialogActions>
    </Dialog>
  );
}

export function OverlaysPage() {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const canWrite = hasPermission('overlays.write');
  const [rawItems, setRawItems] = useState<Record<string, unknown>[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [dialogMode, setDialogMode] = useState<OverlayDialogMode>('create');
  const [dialogInitial, setDialogInitial] = useState<OverlayScheduleRow | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    setError(null);
    setLoading(true);
    try {
      const res = await apiJson<{ items: Record<string, unknown>[] }>(
        active,
        '/v1/display/overlays',
      );
      setRawItems(res.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setLoading(false);
    }
  }, [active]);

  useEffect(() => {
    void load();
  }, [load]);

  const { rows, skipped } = useMemo(() => {
    const parsed: OverlayScheduleRow[] = [];
    let bad = 0;
    for (const raw of rawItems) {
      const row = parseOverlayRow(raw);
      if (row) parsed.push(row);
      else bad += 1;
    }
    return { rows: parsed, skipped: bad };
  }, [rawItems]);

  /** Re-evaluate “today” when the list reloads (operator refresh or navigation). */
  const [evalNow, setEvalNow] = useState(() => new Date());
  useEffect(() => {
    setEvalNow(new Date());
  }, [rawItems]);

  const sorted = useMemo(() => sortSchedules(rows, evalNow), [rows, evalNow]);

  const activeTodayCount = useMemo(
    () => rows.filter((r) => matchesOverlaySchedule(r, evalNow)).length,
    [rows, evalNow],
  );

  const deleteRow = useCallback(
    async (id: string) => {
      if (!active) return;
      if (!window.confirm(`Delete overlay schedule “${id}”?`)) return;
      setError(null);
      try {
        await apiFetch(active, `/v1/display/overlays/${encodeURIComponent(id)}`, {
          method: 'DELETE',
        });
        await load();
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    },
    [active, load],
  );

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={2}>
      <Stack direction="row" alignItems="flex-start" justifyContent="space-between" spacing={2}>
        <Box>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5, maxWidth: 720 }}>
            SQLite table <code>overlays</code>: each row is a calendar rule on the display (local
            date) with <code>overlay_type</code> (like <code>screen_type</code>) and{' '}
            <code>config_json</code> (phrases in <code>messages</code>). Built-in renderers today:{' '}
            <code>hearts_rain</code>, <code>birthday_confetti</code>, <code>bouncing_message</code>.
            API: <code>docs/pi/api.md</code>.
          </Typography>
        </Box>
        <Stack direction="row" spacing={0.5} alignItems="center">
          {canWrite && (
            <Button
              startIcon={<AddIcon />}
              variant="outlined"
              size="small"
              onClick={() => {
                setDialogMode('create');
                setDialogInitial(null);
                setDialogOpen(true);
              }}
            >
              Add schedule
            </Button>
          )}
          <Tooltip title="Reload schedules">
            <span>
              <IconButton onClick={() => void load()} disabled={loading} aria-label="Reload overlays">
                <RefreshIcon />
              </IconButton>
            </span>
          </Tooltip>
        </Stack>
      </Stack>

      {activeTodayCount > 0 && (
        <Alert severity="info" icon={<TodayOutlinedIcon fontSize="inherit" />}>
          {activeTodayCount === 1
            ? 'One schedule matches today’s date on this machine’s calendar.'
            : `${activeTodayCount} schedules match today’s date on this machine’s calendar.`}{' '}
          The display still respects each row’s <strong>Enabled</strong> switch and the global
          overlay toggle in SQLite.
        </Alert>
      )}

      {error && <Alert severity="error">{error}</Alert>}
      {skipped > 0 && (
        <Alert severity="warning">
          Skipped {skipped} row(s) with missing or invalid <code>id</code>.
        </Alert>
      )}

      {sorted.map((row) => {
        const firesToday = matchesOverlaySchedule(row, evalNow);
        const messages = decodeMessagesFromConfig(row.config_json);
        const typeLabel = overlayTypeLabel(row.overlay_type);

        return (
          <Card key={row.id} variant="outlined">
            <CardContent>
              <Stack spacing={1.5}>
                <Stack
                  direction={{ xs: 'column', sm: 'row' }}
                  spacing={1}
                  alignItems={{ xs: 'flex-start', sm: 'center' }}
                  justifyContent="space-between"
                >
                  <Box>
                    <Typography variant="subtitle1" fontWeight={700}>
                      {row.label.trim() || row.id}
                    </Typography>
                    <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'monospace' }}>
                      {row.id}
                    </Typography>
                  </Box>
                  <Stack direction="row" flexWrap="wrap" gap={0.75} useFlexGap>
                    {firesToday && (
                      <Chip
                        size="small"
                        color="primary"
                        variant="outlined"
                        icon={<TodayOutlinedIcon />}
                        label="Matches today"
                      />
                    )}
                    <Chip
                      size="small"
                      label={row.enabled ? 'Enabled' : 'Disabled'}
                      color={row.enabled ? 'success' : 'default'}
                      variant={row.enabled ? 'filled' : 'outlined'}
                    />
                    <Chip size="small" label={typeLabel} variant="outlined" />
                    <Chip size="small" label={scheduleKindLabel(row)} variant="outlined" />
                  </Stack>
                </Stack>

                <Divider />

                <Stack direction="row" spacing={1} alignItems="flex-start">
                  <CalendarMonthOutlinedIcon color="action" sx={{ mt: 0.25 }} fontSize="small" />
                  <Box>
                    <Typography variant="caption" color="text.secondary" fontWeight={600}>
                      When it runs
                    </Typography>
                    <Typography variant="body2">{scheduleSummary(row)}</Typography>
                  </Box>
                </Stack>

                {messages.length > 0 && (
                  <Box>
                    <Typography variant="caption" color="text.secondary" fontWeight={600}>
                      Messages
                    </Typography>
                    <Stack component="ul" sx={{ m: 0, pl: 2.5, mt: 0.25 }}>
                      {messages.map((m) => (
                        <Typography key={m} component="li" variant="body2">
                          {m}
                        </Typography>
                      ))}
                    </Stack>
                  </Box>
                )}

                <Accordion disableGutters elevation={0} sx={{ '&:before': { display: 'none' } }}>
                  <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                    <Typography variant="caption" color="text.secondary">
                      Raw JSON (schemas and config)
                    </Typography>
                  </AccordionSummary>
                  <AccordionDetails sx={{ pt: 0 }}>
                    <Typography
                      component="pre"
                      sx={{ fontFamily: 'monospace', fontSize: 12, m: 0, whiteSpace: 'pre-wrap' }}
                    >
                      {JSON.stringify(
                        rawItems.find((x) => String(x.id ?? '') === row.id) ?? row,
                        null,
                        2,
                      )}
                    </Typography>
                  </AccordionDetails>
                </Accordion>
              </Stack>
            </CardContent>
            {canWrite && (
              <CardActions>
                <Button
                  size="small"
                  startIcon={<EditIcon />}
                  onClick={() => {
                    setDialogMode('edit');
                    setDialogInitial(row);
                    setDialogOpen(true);
                  }}
                >
                  Edit
                </Button>
                <Button
                  size="small"
                  color="error"
                  startIcon={<DeleteOutlineIcon />}
                  onClick={() => void deleteRow(row.id)}
                >
                  Delete
                </Button>
              </CardActions>
            )}
          </Card>
        );
      })}

      {sorted.length === 0 && !error && (
        <Typography color="text.secondary">No overlay schedules returned.</Typography>
      )}

      <OverlayScheduleDialog
        open={dialogOpen}
        mode={dialogMode}
        active={active}
        initial={dialogInitial}
        allRows={rows}
        onClose={() => setDialogOpen(false)}
        onSaved={() => void load()}
      />
    </Stack>
  );
}
