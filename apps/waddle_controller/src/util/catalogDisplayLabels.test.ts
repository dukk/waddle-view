import { describe, expect, it } from 'vitest';
import {
  alertLifecycleStatus,
  alertSourceLabel,
  alertSeverityLabel,
  categoryIdsForRow,
  categoryLabelsForRow,
  newsSourceLabel,
  parseCalendarEventSource,
} from '@/util/catalogDisplayLabels';

describe('catalogDisplayLabels', () => {
  it('alertSeverityLabel maps known severities', () => {
    expect(alertSeverityLabel('info')).toBe('Info');
    expect(alertSeverityLabel('auth')).toBe('Sign-in required');
    expect(alertSeverityLabel('unknown_sev')).toBe('Unknown Sev');
  });

  it('alertSourceLabel maps known sources', () => {
    expect(alertSourceLabel('adoption')).toBe('Display adoption');
    expect(alertSourceLabel('microsoft_graph')).toBe('Microsoft sign-in');
  });

  it('alertLifecycleStatus respects dismissed and expiry', () => {
    expect(
      alertLifecycleStatus({ dismissed_at_ms: 1 }, 100),
    ).toBe('dismissed');
    expect(
      alertLifecycleStatus({ expires_at_ms: 50 }, 100),
    ).toBe('expired');
    expect(
      alertLifecycleStatus({ expires_at_ms: 200 }, 100),
    ).toBe('active');
  });

  it('categoryIdsForRow reads category_ids and category_id', () => {
    expect(categoryIdsForRow({ category_ids: ['a', 'b'] })).toEqual(['a', 'b']);
    expect(categoryIdsForRow({ category_id: 'work' })).toEqual(['work']);
    expect(categoryIdsForRow({ category: 'news' })).toEqual(['news']);
  });

  it('categoryLabelsForRow resolves curator labels', () => {
    expect(
      categoryLabelsForRow(
        { category_id: 'family' },
        [{ id: 'family', label: 'Family' }],
      ),
    ).toEqual(['Family']);
  });

  it('parseCalendarEventSource resolves google account label', () => {
    const detail = parseCalendarEventSource('google_calendar:acct1', {
      integrationAccounts: [{ id: 'acct1', label: 'Home Google' }],
      icalFeedsById: {},
    });
    expect(detail.integrationLabel).toBe('Google Calendar');
    expect(detail.accountOrFeedLabel).toBe('Home Google');
  });

  it('parseCalendarEventSource resolves ical feed label', () => {
    const detail = parseCalendarEventSource('ical_feed:feed-1', {
      integrationAccounts: [],
      icalFeedsById: {
        'feed-1': { label: 'School menu', url: 'https://example.com/ical' },
      },
    });
    expect(detail.accountOrFeedLabel).toBe('School menu');
  });

  it('newsSourceLabel includes feed title', () => {
    expect(
      newsSourceLabel(
        { integration_type: 'news_rss', feed_id: 'f1' },
        [{ id: 'f1', title: 'Local paper', url: 'https://news.test/rss' }],
      ),
    ).toBe('RSS News · Local paper');
  });
});
