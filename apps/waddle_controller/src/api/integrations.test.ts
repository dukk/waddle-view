import { describe, expect, it } from 'vitest';
import { buildIntegrationsQuery } from '@/api/integrations';

describe('buildIntegrationsQuery', () => {
  it('sets enabled, paging, and sort params', () => {
    const qs = buildIntegrationsQuery({
      enabled: true,
      limit: 25,
      offset: 50,
      sort: 'poll_seconds',
      order: 'desc',
    });
    expect(qs).toContain('enabled=true');
    expect(qs).toContain('limit=25');
    expect(qs).toContain('offset=50');
    expect(qs).toContain('sort=poll_seconds');
    expect(qs).toContain('order=desc');
  });

  it('includes optional filters when set', () => {
    const qs = buildIntegrationsQuery({
      enabled: false,
      limit: 10,
      offset: 0,
      family: 'news',
      q: 'rss',
      secrets_configured: false,
      accounts_configured: true,
      facets: 'family',
    });
    expect(qs).toContain('enabled=false');
    expect(qs).toContain('family=news');
    expect(qs).toContain('q=rss');
    expect(qs).toContain('secrets_configured=false');
    expect(qs).toContain('accounts_configured=true');
    expect(qs).toContain('facets=family');
  });
});
