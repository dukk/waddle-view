/// LinkedIn OAuth public client id ([SecretStore] key).
const String kLinkedInClientIdSecretKey = 'provider:client_id:linkedin';

/// [SecretStore] access token for one LinkedIn account.
String linkedInAccessTokenSecret(String linkedInAccountKey) =>
    'provider:access_token:linkedin:$linkedInAccountKey';
