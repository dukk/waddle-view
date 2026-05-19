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
                { id: 'cal-1', name: 'Work', categoryIds: ['work', 'family'] },
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
    expect(state.calendars[0]?.categoryIds).toEqual(['work', 'family']);
  });

  it('defaults past and future days to 30', () => {
    const state = parseOutlookCalendarConfig({ accounts: [] });
    expect(state.pastDays).toBe(30);
    expect(state.futureDays).toBe(30);
  });

  it('builds config_json with categoryIds array', () => {
    const json = buildOutlookCalendarConfigJson({
      graphAccountKey: 'work',
      pastDays: 30,
      futureDays: 30,
      calendars: [
        {
          id: 'cal-1',
          name: 'Work',
          categoryIds: ['work', 'family'],
          selected: true,
        },
        {
          id: 'cal-2',
          name: 'Personal',
          categoryIds: [],
          selected: false,
        },
      ],
    });
    const accounts = json.accounts as Record<string, unknown>[];
    expect(accounts).toHaveLength(1);
    const sources = accounts[0]?.sources as Record<string, unknown>[];
    const calendars = sources[0]?.calendars as Record<string, unknown>[];
    expect(calendars).toHaveLength(1);
    expect(calendars[0]?.categoryIds).toEqual(['work', 'family']);
  });

  it('mergeOutlookCalendarsWithSaved preserves prior categories and selection', () => {
    const merged = mergeOutlookCalendarsWithSaved(
      [
        { id: 'cal-1', name: 'Work' },
        { id: 'cal-2', name: 'Personal' },
      ],
      [{ id: 'cal-1', name: 'Work', categoryIds: ['work'], selected: true }],
    );
    expect(merged[0]?.selected).toBe(true);
    expect(merged[0]?.categoryIds).toEqual(['work']);
    expect(merged[1]?.selected).toBe(false);
  });
});
