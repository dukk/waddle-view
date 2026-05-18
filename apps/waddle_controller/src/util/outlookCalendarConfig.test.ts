import { describe, expect, it } from 'vitest';
import {
  buildOutlookCalendarConfigJson,
  mergeOutlookCalendarsWithSaved,
  parseOutlookCalendarConfig,
} from './outlookCalendarConfig';

describe('outlookCalendarConfig', () => {
  it('parses account key, window, and calendar selections', () => {
    const state = parseOutlookCalendarConfig({
      pastDays: 7,
      futureDays: 21,
      accounts: [
        {
          graphAccountKey: 'work',
          sources: [
            {
              mailbox: 'me',
              calendars: [
                { id: 'cal-1', name: 'Work', category: 'work' },
                'Personal',
              ],
            },
          ],
        },
      ],
    });
    expect(state.graphAccountKey).toBe('work');
    expect(state.pastDays).toBe(7);
    expect(state.futureDays).toBe(21);
    expect(state.calendars).toHaveLength(2);
    expect(state.calendars[0]?.categoryId).toBe('work');
  });

  it('builds config_json without exposing empty accounts', () => {
    const json = buildOutlookCalendarConfigJson({
      graphAccountKey: 'work',
      pastDays: 14,
      futureDays: 14,
      calendars: [
        {
          id: 'cal-1',
          name: 'Work',
          categoryId: 'work',
          selected: true,
        },
        {
          id: 'cal-2',
          name: 'Personal',
          categoryId: '',
          selected: false,
        },
      ],
    });
    const accounts = json.accounts as Record<string, unknown>[];
    expect(accounts).toHaveLength(1);
    const sources = accounts[0]?.sources as Record<string, unknown>[];
    const calendars = sources[0]?.calendars as Record<string, unknown>[];
    expect(calendars).toHaveLength(1);
    expect(calendars[0]?.category).toBe('work');
  });

  it('mergeOutlookCalendarsWithSaved preserves prior category and selection', () => {
    const merged = mergeOutlookCalendarsWithSaved(
      [
        { id: 'cal-1', name: 'Work' },
        { id: 'cal-2', name: 'Personal' },
      ],
      [{ id: 'cal-1', name: 'Work', categoryId: 'work', selected: true }],
    );
    expect(merged[0]?.selected).toBe(true);
    expect(merged[0]?.categoryId).toBe('work');
    expect(merged[1]?.selected).toBe(false);
  });
});
