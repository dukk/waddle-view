/** Data tabs that support operator manual entry (controller Data page). */
export type ManualEntryKind =
  | 'calendar_events'
  | 'jokes'
  | 'photos'
  | 'trivia'
  | 'videos'
  | 'quoterism_quotes';

export const MANUAL_ENTRY_KINDS: ReadonlySet<ManualEntryKind> = new Set([
  'calendar_events',
  'jokes',
  'photos',
  'trivia',
  'videos',
  'quoterism_quotes',
]);

export function isManualEntryKind(kind: string): kind is ManualEntryKind {
  return MANUAL_ENTRY_KINDS.has(kind as ManualEntryKind);
}

export function manualEntryPostPath(kind: ManualEntryKind): string {
  switch (kind) {
    case 'photos':
      return '/v1/curator/manual/photos';
    case 'videos':
      return '/v1/curator/manual/videos';
    case 'jokes':
      return '/v1/curator/manual/jokes';
    case 'trivia':
      return '/v1/curator/manual/trivia';
    case 'calendar_events':
      return '/v1/curator/manual/calendar-events';
    case 'quoterism_quotes':
      return '/v1/curator/manual/quoterism-quotes';
  }
}

export function manualEntryDialogTitle(kind: ManualEntryKind): string {
  switch (kind) {
    case 'photos':
      return 'Add photo';
    case 'videos':
      return 'Add video';
    case 'jokes':
      return 'Add joke';
    case 'trivia':
      return 'Add trivia';
    case 'calendar_events':
      return 'Add calendar event';
    case 'quoterism_quotes':
      return 'Add quote';
  }
}
