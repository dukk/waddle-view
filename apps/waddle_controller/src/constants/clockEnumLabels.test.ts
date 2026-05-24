import { describe, expect, it } from 'vitest';
import {
  ANALOG_DIAL_LABELS_OPTIONS,
  enumLabelForValue,
  INVITE_ROLE_OPTIONS,
  readEnumLabelsFromSchema,
} from './clockEnumLabels';

describe('enumLabelForValue', () => {
  it('returns label for known value', () => {
    expect(enumLabelForValue(ANALOG_DIAL_LABELS_OPTIONS, 'roman')).toBe('Roman numerals');
    expect(enumLabelForValue(INVITE_ROLE_OPTIONS, 'operator')).toBe('Operator');
  });

  it('falls back to raw value when unknown', () => {
    expect(enumLabelForValue(ANALOG_DIAL_LABELS_OPTIONS, 'unknown_mode')).toBe('unknown_mode');
  });
});

describe('readEnumLabelsFromSchema', () => {
  it('returns string map from x-waddle-enum-labels', () => {
    expect(
      readEnumLabelsFromSchema({
        'x-waddle-enum-labels': { a: 'Alpha', b: 'Beta' },
      }),
    ).toEqual({ a: 'Alpha', b: 'Beta' });
  });

  it('ignores non-string values', () => {
    expect(
      readEnumLabelsFromSchema({
        'x-waddle-enum-labels': { a: 'Alpha', b: 42, c: null },
      }),
    ).toEqual({ a: 'Alpha' });
  });

  it('returns null for missing or invalid shapes', () => {
    expect(readEnumLabelsFromSchema({})).toBeNull();
    expect(readEnumLabelsFromSchema({ 'x-waddle-enum-labels': null })).toBeNull();
    expect(readEnumLabelsFromSchema({ 'x-waddle-enum-labels': [] })).toBeNull();
    expect(readEnumLabelsFromSchema({ 'x-waddle-enum-labels': { a: 1 } })).toBeNull();
  });
});
