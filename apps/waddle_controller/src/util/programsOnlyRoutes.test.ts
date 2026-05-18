import { describe, expect, it } from 'vitest';
import {
  isProgramsOnlyNavRouteAllowed,
  isProgramsOnlyPathAllowed,
} from './programsOnlyRoutes';

describe('isProgramsOnlyPathAllowed', () => {
  const denyAll = () => false;

  it('allows programs and account for any permission set', () => {
    expect(isProgramsOnlyPathAllowed('/programs', denyAll)).toBe(true);
    expect(isProgramsOnlyPathAllowed('/programs/foo', denyAll)).toBe(true);
    expect(isProgramsOnlyPathAllowed('/account', denyAll)).toBe(true);
  });

  it('allows remote only with navigation.control', () => {
    const withNav = (p: string) => p === 'navigation.control';
    expect(isProgramsOnlyPathAllowed('/remote', withNav)).toBe(true);
    expect(isProgramsOnlyPathAllowed('/remote', denyAll)).toBe(false);
  });

  it('allows data with catalog or moderate permission', () => {
    const catalog = (p: string) => p === 'content.catalog_read';
    expect(isProgramsOnlyPathAllowed('/data', catalog)).toBe(true);
    expect(isProgramsOnlyPathAllowed('/data', denyAll)).toBe(false);
  });

  it('allows interests with interests.read or interests.write', () => {
    const readOnly = (p: string) => p === 'interests.read';
    expect(isProgramsOnlyPathAllowed('/interests', readOnly)).toBe(true);
    expect(isProgramsOnlyPathAllowed('/interests', denyAll)).toBe(false);
    const writeOnly = (p: string) => p === 'interests.write';
    expect(isProgramsOnlyPathAllowed('/interests', writeOnly)).toBe(true);
  });

  it('redirects unknown paths', () => {
    expect(isProgramsOnlyPathAllowed('/screens', denyAll)).toBe(false);
  });
});

describe('isProgramsOnlyNavRouteAllowed', () => {
  it('includes interests when interests.read is granted', () => {
    const read = (p: string) => p === 'interests.read';
    expect(isProgramsOnlyNavRouteAllowed('/interests', read)).toBe(true);
    expect(isProgramsOnlyNavRouteAllowed('/interests', () => false)).toBe(false);
  });
});
