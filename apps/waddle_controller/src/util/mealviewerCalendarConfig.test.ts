import { describe, expect, it } from 'vitest';
import {
  buildMealviewerCalendarConfigJson,
  mergeSchoolIntoList,
  parseMealviewerCalendarConfig,
} from './mealviewerCalendarConfig';

describe('mealviewerCalendarConfig', () => {
  it('parses schools and category ids', () => {
    const state = parseMealviewerCalendarConfig({
      pastDays: 7,
      futureDays: 14,
      schools: [
        {
          schoolSlug: 'Elmwood Elementary',
          label: 'Elmwood',
          districtSlug: 'Hopkinton',
          categoryIds: ['school', 'lunch'],
        },
      ],
    });
    expect(state.pastDays).toBe(7);
    expect(state.schools[0].schoolSlug).toBe('ElmwoodElementary');
    expect(state.schools[0].categoryIds).toEqual(['school', 'lunch']);
  });

  it('builds config json for save', () => {
    const built = buildMealviewerCalendarConfigJson({
      pastDays: 30,
      futureDays: 30,
      schools: [
        {
          schoolSlug: 'FooBar',
          label: 'Foo',
          categoryIds: ['a'],
        },
      ],
    });
    expect(built.schools).toEqual([
      { schoolSlug: 'FooBar', label: 'Foo', categoryIds: ['a'] },
    ]);
  });

  it('mergeSchoolIntoList replaces same slug', () => {
    const merged = mergeSchoolIntoList(
      [{ schoolSlug: 'A', label: 'Old', categoryIds: [] }],
      { schoolSlug: 'A', label: 'New', categoryIds: ['x'] },
    );
    expect(merged).toHaveLength(1);
    expect(merged[0].label).toBe('New');
  });
});
