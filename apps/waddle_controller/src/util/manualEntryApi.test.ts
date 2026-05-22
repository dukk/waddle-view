import { describe, expect, it } from 'vitest';
import {
  isManualEntryKind,
  manualEntryDialogTitle,
  manualEntryPostPath,
  MANUAL_ENTRY_KINDS,
} from './manualEntryApi';

describe('manualEntryApi', () => {
  it('MANUAL_ENTRY_KINDS contains all supported kinds', () => {
    expect(MANUAL_ENTRY_KINDS.size).toBe(6);
    expect(isManualEntryKind('photos')).toBe(true);
    expect(isManualEntryKind('unknown')).toBe(false);
  });

  it('manualEntryPostPath maps each kind to curator manual routes', () => {
    expect(manualEntryPostPath('photos')).toBe('/v1/curator/manual/photos');
    expect(manualEntryPostPath('videos')).toBe('/v1/curator/manual/videos');
    expect(manualEntryPostPath('jokes')).toBe('/v1/curator/manual/jokes');
    expect(manualEntryPostPath('trivia')).toBe('/v1/curator/manual/trivia');
    expect(manualEntryPostPath('calendar_events')).toBe('/v1/curator/manual/calendar-events');
    expect(manualEntryPostPath('quoterism_quotes')).toBe('/v1/curator/manual/quoterism-quotes');
  });

  it('manualEntryDialogTitle returns operator-facing labels', () => {
    expect(manualEntryDialogTitle('photos')).toBe('Add photo');
    expect(manualEntryDialogTitle('calendar_events')).toBe('Add calendar event');
    expect(manualEntryDialogTitle('quoterism_quotes')).toBe('Add quote');
  });
});
