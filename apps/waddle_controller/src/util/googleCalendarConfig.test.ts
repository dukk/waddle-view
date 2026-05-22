import { describe, expect, it } from 'vitest';
import {
  buildGoogleCalendarConfigJson,
  googleCalendarConfigReady,
  mergeGoogleCalendarsWithSaved,
  parseGoogleCalendarConfig,
} from './googleCalendarConfig';

describe('googleCalendarConfig', () => {
  it('parseGoogleCalendarConfig reads account, window, and calendars', () => {
    const state = parseGoogleCalendarConfig({
      pastDays: 5,
      futureDays: 10,
      accounts: [
        {
          googleAccountKey: 'work',
          sources: [
            {
              calendars: [
                { calendar: 'primary', categoryIds: ['family'] },
                'holidays',
              ],
            },
          ],
        },
      ],
    });
    expect(state.googleAccountKey).toBe('work');
    expect(state.pastDays).toBe(5);
    expect(state.futureDays).toBe(10);
    expect(state.calendars).toHaveLength(2);
    expect(state.calendars[0]?.id).toBe('primary');
    expect(state.calendars[0]?.categoryIds).toEqual(['family']);
  });

  it('buildGoogleCalendarConfigJson omits baseUrl and writes selected calendars', () => {
    const built = buildGoogleCalendarConfigJson({
      googleAccountKey: 'work',
      pastDays: 30,
      futureDays: 30,
      calendars: [
        { id: 'primary', name: 'Primary', categoryIds: ['family'], selected: true },
        { id: 'other', name: 'Other', categoryIds: [], selected: false },
      ],
    });
    expect(built).not.toHaveProperty('baseUrl');
    const accounts = built.accounts as { googleAccountKey: string; sources: unknown[] }[];
    expect(accounts[0]?.googleAccountKey).toBe('work');
    const sources = accounts[0]?.sources as { calendars: { calendar: string }[] }[];
    expect(sources[0]?.calendars).toHaveLength(1);
    expect(sources[0]?.calendars[0]?.calendar).toBe('primary');
  });

  it('mergeGoogleCalendarsWithSaved preserves prior selection', () => {
    const merged = mergeGoogleCalendarsWithSaved(
      [{ id: 'a', name: 'A' }],
      [{ id: 'a', name: 'Old', categoryIds: ['work'], selected: true }],
    );
    expect(merged[0]?.selected).toBe(true);
    expect(merged[0]?.categoryIds).toEqual(['work']);
  });

  it('googleCalendarConfigReady requires configured account and selection', () => {
    expect(
      googleCalendarConfigReady(
        {
          googleAccountKey: 'work',
          pastDays: 30,
          futureDays: 30,
          calendars: [{ id: 'a', name: 'A', categoryIds: [], selected: true }],
        },
        [
          {
            id: 'work',
            label: 'Work',
            configured: true,
            account_type: 'google',
            account_type_label: 'Google',
            integration_types: ['calendar_google'],
          },
        ],
      ),
    ).toBe(true);
    expect(
      googleCalendarConfigReady(
        {
          googleAccountKey: 'work',
          pastDays: 30,
          futureDays: 30,
          calendars: [{ id: 'a', name: 'A', categoryIds: [], selected: false }],
        },
        [
          {
            id: 'work',
            label: 'Work',
            configured: true,
            account_type: 'google',
            account_type_label: 'Google',
            integration_types: ['calendar_google'],
          },
        ],
      ),
    ).toBe(false);
  });
});
