import { describe, expect, it, vi } from 'vitest';
import { isValidIcalFeedUrl } from './icalCalendarConfig';
import {
  feedFromSuggestion,
  feedListHasUrl,
  ICAL_SUGGESTED_WEBCAL_GURU_FEEDS,
  kWebcalGuruSignupUrl,
  normalizeIcalFeedUrlForCompare,
} from './icalSuggestedFeeds';

const expectedLabels = [
  'U.S. Election Calendar',
  'Awareness Days',
  'Food and Drink Awareness',
  'Funny Holidays',
  'Good to Know',
  'Word of the day',
  'Premiere movies',
  'U.S. Federal Holidays',
  'National elections',
  'UN Observances',
];

describe('icalSuggestedFeeds', () => {
  it('catalog has 10 WebCal.Guru feeds with expected labels', () => {
    expect(ICAL_SUGGESTED_WEBCAL_GURU_FEEDS).toHaveLength(10);
    expect(ICAL_SUGGESTED_WEBCAL_GURU_FEEDS.map((f) => f.label)).toEqual(expectedLabels);
  });

  it('every catalog url is a valid iCal feed url', () => {
    for (const feed of ICAL_SUGGESTED_WEBCAL_GURU_FEEDS) {
      expect(isValidIcalFeedUrl(feed.url)).toBe(true);
      expect(feed.url).toMatch(
        /^https:\/\/www\.webcal\.guru\/en-US\/download_calendar\?calendar_instance_id=\d+$/,
      );
    }
  });

  it('signup url points to WebCal.Guru create account', () => {
    expect(kWebcalGuruSignupUrl).toBe('https://www.webcal.guru/en-US/create_account');
  });

  it('normalizeIcalFeedUrlForCompare treats trailing whitespace as equal', () => {
    const a = 'https://www.webcal.guru/en-US/download_calendar?calendar_instance_id=41';
    const b = '  https://www.webcal.guru/en-US/download_calendar?calendar_instance_id=41  ';
    expect(normalizeIcalFeedUrlForCompare(a)).toBe(normalizeIcalFeedUrlForCompare(b));
  });

  it('feedListHasUrl detects configured feeds by url', () => {
    const url = ICAL_SUGGESTED_WEBCAL_GURU_FEEDS[7].url;
    expect(
      feedListHasUrl(
        [{ id: 'x', url: `${url} `, categoryId: 'holiday' }],
        url,
      ),
    ).toBe(true);
    expect(feedListHasUrl([], url)).toBe(false);
  });

  it('feedFromSuggestion assigns id label and category', () => {
    vi.stubGlobal('crypto', { randomUUID: () => 'suggested-feed-id' });
    const suggestion = ICAL_SUGGESTED_WEBCAL_GURU_FEEDS[0];
    const feed = feedFromSuggestion(suggestion, 'events');
    expect(feed).toEqual({
      id: 'suggested-feed-id',
      url: suggestion.url,
      label: suggestion.label,
      categoryId: 'events',
    });
    vi.unstubAllGlobals();
  });
});
