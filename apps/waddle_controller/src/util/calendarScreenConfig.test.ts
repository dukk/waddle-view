import { describe, expect, it } from 'vitest';
import { applyCalendarMonthDefaults, upcomingTime12HourFromControllerFormat } from '@/util/calendarScreenConfig';

describe('upcomingTime12HourFromControllerFormat', () => {
  it('maps 12h to true', () => {
    expect(upcomingTime12HourFromControllerFormat('12h')).toBe(true);
  });

  it('maps 24h to false', () => {
    expect(upcomingTime12HourFromControllerFormat('24h')).toBe(false);
  });
});

describe('applyCalendarMonthDefaults', () => {
  it('fills hidePastEvents and time format when missing', () => {
    expect(applyCalendarMonthDefaults({}, '24h')).toEqual({
      hidePastEvents: true,
      upcomingTime12Hour: false,
    });
  });

  it('does not override explicit values', () => {
    expect(
      applyCalendarMonthDefaults(
        { hidePastEvents: false, upcomingTime12Hour: true },
        '24h',
      ),
    ).toEqual({ hidePastEvents: false, upcomingTime12Hour: true });
  });
});
