/** Operator-facing help when configuring an OAuth app client ID. */
export type OAuthClientIdRegistrationGuide = {
  message: string;
  href: string;
  linkLabel: string;
};

const guides: Record<string, OAuthClientIdRegistrationGuide> = {
  google: {
    message:
      'You need a Google account and an OAuth client ID from Google Cloud.',
    href: 'https://console.cloud.google.com/apis/credentials',
    linkLabel: 'Google Cloud Console — create OAuth credentials',
  },
  microsoft_graph: {
    message:
      'You need a Microsoft account and an app registration in Entra ID.',
    href: 'https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/CreateApplicationBlade',
    linkLabel: 'Microsoft Entra — register an application',
  },
  facebook: {
    message: 'You need a Meta developer account and a Facebook app.',
    href: 'https://developers.facebook.com/apps/',
    linkLabel: 'Meta for Developers — create an app',
  },
  twitter: {
    message: 'You need an X developer account and a project with OAuth 2.0 enabled.',
    href: 'https://developer.x.com/en/portal/dashboard',
    linkLabel: 'X Developer Portal',
  },
  linkedin: {
    message: 'You need a LinkedIn developer account and an app.',
    href: 'https://www.linkedin.com/developers/apps',
    linkLabel: 'LinkedIn Developer Portal — create an app',
  },
};

export function oauthClientIdRegistrationGuide(
  providerId: string,
): OAuthClientIdRegistrationGuide | undefined {
  return guides[providerId];
}
