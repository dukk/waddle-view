/// X (Twitter) OAuth public client id ([SecretStore] key).
const String kTwitterClientIdSecretKey = 'provider:client_id:twitter';

/// [SecretStore] access token for one X account.
String twitterAccessTokenSecret(String twitterAccountKey) =>
    'provider:access_token:twitter:$twitterAccountKey';
