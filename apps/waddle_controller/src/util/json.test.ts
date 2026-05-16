import { describe, expect, it } from 'vitest';
import { parseJsonObject } from './json';

describe('parseJsonObject', () => {
  it('returns empty object for nullish values', () => {
    expect(parseJsonObject(null)).toEqual({});
    expect(parseJsonObject(undefined)).toEqual({});
  });

  it('parses JSON strings into objects', () => {
    expect(parseJsonObject('{"a":1}')).toEqual({ a: 1 });
  });

  it('returns empty object for invalid or non-object JSON strings', () => {
    expect(parseJsonObject('not json')).toEqual({});
    expect(parseJsonObject('[]')).toEqual({});
    expect(parseJsonObject('')).toEqual({});
  });

  it('passes through plain objects', () => {
    const obj = { x: true };
    expect(parseJsonObject(obj)).toBe(obj);
  });

  it('rejects arrays and primitives', () => {
    expect(parseJsonObject([1, 2])).toEqual({});
    expect(parseJsonObject(42)).toEqual({});
  });
});
