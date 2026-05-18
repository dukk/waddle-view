import { describe, expect, it } from 'vitest';
import { oauthClientIdRegistrationGuide } from './oauthClientIdRegistration';

describe('oauthClientIdRegistrationGuide', () => {
  it('returns guide for known oauth providers', () => {
    const google = oauthClientIdRegistrationGuide('google');
    expect(google?.href).toContain('console.cloud.google.com');
    expect(google?.message.length).toBeGreaterThan(0);

    const microsoft = oauthClientIdRegistrationGuide('microsoft_graph');
    expect(microsoft?.href).toContain('entra.microsoft.com');

    expect(oauthClientIdRegistrationGuide('facebook')?.href).toContain(
      'developers.facebook.com',
    );
    expect(oauthClientIdRegistrationGuide('twitter')?.href).toContain('developer.x.com');
    expect(oauthClientIdRegistrationGuide('linkedin')?.href).toContain(
      'linkedin.com/developers',
    );
  });

  it('returns undefined for unknown providers', () => {
    expect(oauthClientIdRegistrationGuide('unknown')).toBeUndefined();
  });
});
