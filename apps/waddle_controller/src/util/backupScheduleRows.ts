import type { BackupTarget } from '@/api/bffBackups';
import type { SavedDisplay } from '@/storage/displays';
import type { DisplayReachability } from '@/util/displayHealth';
import { formatScheduleSummary, scheduleFromTarget } from '@/util/backupSchedule';
import {
  buildColumnSortOptions,
  columnSortToolbarOptions,
  compareBool,
  compareLocale,
  tieBreakLocale,
  type ColumnSortField,
} from '@/util/dataViewColumnSort';

export type BackupScheduleRow = {
  display: SavedDisplay;
  target: BackupTarget | null;
  reachability?: DisplayReachability;
  scheduleSummary: string;
  enabled: boolean;
  lastRunLabel: string;
};

export const BACKUP_SCHEDULE_SORT_FIELDS: ColumnSortField<BackupScheduleRow>[] = [
  {
    id: 'display',
    label: 'Display',
    compare: (a, b) =>
      tieBreakLocale(compareLocale(a.display.label, b.display.label), a.display.id, b.display.id),
  },
  {
    id: 'schedule',
    label: 'Schedule',
    compare: (a, b) =>
      tieBreakLocale(compareLocale(a.scheduleSummary, b.scheduleSummary), a.display.id, b.display.id),
  },
  {
    id: 'last_run',
    label: 'Last run',
    compare: (a, b) =>
      tieBreakLocale(
        compareLocale(a.target?.lastRunAt ?? '', b.target?.lastRunAt ?? ''),
        a.display.id,
        b.display.id,
      ),
  },
  {
    id: 'scheduled_pulls',
    label: 'Scheduled pulls',
    compare: (a, b) =>
      tieBreakLocale(compareBool(a.enabled, b.enabled), a.display.id, b.display.id),
  },
];

export const BACKUP_SCHEDULE_SORT_OPTIONS = buildColumnSortOptions(BACKUP_SCHEDULE_SORT_FIELDS);
export const BACKUP_SCHEDULE_SORT_TOOLBAR = columnSortToolbarOptions(BACKUP_SCHEDULE_SORT_FIELDS);

export function buildBackupScheduleRows(
  displays: SavedDisplay[],
  targetByDisplayId: Map<string, BackupTarget>,
  reachability: Record<string, DisplayReachability | undefined>,
): BackupScheduleRow[] {
  return displays.map((display) => {
    const target = targetByDisplayId.get(display.id) ?? null;
    const schedule = target ? scheduleFromTarget(target.schedule) : null;
    const scheduleSummary = schedule
      ? formatScheduleSummary(schedule)
      : 'Not configured';
    const enabled = target?.enabled ?? false;
    let lastRunLabel = '—';
    if (target?.lastRunAt) {
      lastRunLabel = new Date(target.lastRunAt).toLocaleString();
      if (target.lastStatus) {
        lastRunLabel += ` (${target.lastStatus})`;
      }
      if (target.lastError) {
        lastRunLabel += ` — ${target.lastError}`;
      }
    }
    return {
      display,
      target,
      reachability: reachability[display.id],
      scheduleSummary,
      enabled,
      lastRunLabel,
    };
  });
}

export function backupScheduleSearchMatches(row: BackupScheduleRow, q: string): boolean {
  const haystack = [
    row.display.label,
    row.display.baseUrl,
    row.display.id,
    row.scheduleSummary,
    row.lastRunLabel,
    row.target?.lastStatus ?? '',
    row.target?.lastError ?? '',
  ]
    .join(' ')
    .toLowerCase();
  return haystack.includes(q);
}
