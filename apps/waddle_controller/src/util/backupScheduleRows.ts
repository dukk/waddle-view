import type { BackupTarget } from '@/api/bffBackups';
import type { SavedDisplay } from '@/storage/displays';
import type { DisplayReachability } from '@/util/displayHealth';
import { formatScheduleSummary, scheduleFromTarget } from '@/util/backupSchedule';
import type { SortOption } from '@/util/clientListPipeline';

export type BackupScheduleRow = {
  display: SavedDisplay;
  target: BackupTarget | null;
  reachability?: DisplayReachability;
  scheduleSummary: string;
  enabled: boolean;
  lastRunLabel: string;
};

export const BACKUP_SCHEDULE_SORT_OPTIONS: SortOption<BackupScheduleRow>[] = [
  {
    id: 'label_asc',
    label: 'Name (A–Z)',
    compare: (a, b) => a.display.label.localeCompare(b.display.label),
  },
  {
    id: 'label_desc',
    label: 'Name (Z–A)',
    compare: (a, b) => b.display.label.localeCompare(a.display.label),
  },
  {
    id: 'last_run_desc',
    label: 'Last run (newest)',
    compare: (a, b) =>
      (b.target?.lastRunAt ?? '').localeCompare(a.target?.lastRunAt ?? ''),
  },
  {
    id: 'last_run_asc',
    label: 'Last run (oldest)',
    compare: (a, b) =>
      (a.target?.lastRunAt ?? '').localeCompare(b.target?.lastRunAt ?? ''),
  },
  {
    id: 'enabled_first',
    label: 'Enabled first',
    compare: (a, b) => Number(b.enabled) - Number(a.enabled),
  },
];

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
