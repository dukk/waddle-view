import { describe, expect, it } from 'vitest';
import {
  categoryLabelsForConfig,
  normalizeConfigCategoryFields,
  resolveCategoryLabel,
  resolveCategoryLabels,
} from '@/util/contentCategorySelect';

const categories = [
  { id: 'general', label: 'General' },
  { id: 'science', label: 'Science' },
];

describe('resolveCategoryLabel', () => {
  it('maps id to label', () => {
    expect(resolveCategoryLabel('general', categories)).toBe('General');
  });

  it('passes through label', () => {
    expect(resolveCategoryLabel('Science', categories)).toBe('Science');
  });

  it('returns orphan stored value', () => {
    expect(resolveCategoryLabel('orphan', categories)).toBe('orphan');
  });
});

describe('resolveCategoryLabels', () => {
  it('normalizes mixed ids and labels', () => {
    expect(resolveCategoryLabels(['general', 'Science'], categories)).toEqual([
      'General',
      'Science',
    ]);
  });
});

describe('categoryLabelsForConfig', () => {
  it('reads categoryName', () => {
    expect(categoryLabelsForConfig({ categoryName: 'general' }, categories)).toEqual([
      'General',
    ]);
  });

  it('reads categoryNames', () => {
    expect(
      categoryLabelsForConfig({ categoryNames: ['science', 'general'] }, categories),
    ).toEqual(['Science', 'General']);
  });
});

describe('normalizeConfigCategoryFields', () => {
  it('rewrites ids to labels', () => {
    expect(
      normalizeConfigCategoryFields(
        { categoryName: 'general', categoryNames: ['science'] },
        categories,
      ),
    ).toEqual({ categoryName: 'General', categoryNames: ['Science'] });
  });
});
