/// Facebook OAuth public app id ([SecretStore] key).
const String kFacebookClientIdSecretKey = 'provider:client_id:facebook';

/// [Alerts.source] for Facebook sign-in prompts.
const String kFacebookOAuthAlertSource = 'news_facebook';

/// Graph API scopes for page and group feed reads.
const String kFacebookNewsOAuthScopes =
    'pages_read_engagement,pages_show_list,groups_access_member';

/// Last successful Facebook news collect (poll gate).
const String kFacebookNewsLastCollectKvKey =
    'provider.news_facebook.last_collect_ms';

/// Milliseconds since epoch when the Facebook access token expires.
String kFacebookAccessTokenExpiresAtKvKey(String facebookAccountKey) =>
    'facebook.access_token_expires_at_ms.$facebookAccountKey';

/// Throttle device-code prompts per account.
String kFacebookNewsLastDevicePromptKvKey(String facebookAccountKey) =>
    'provider.news_facebook.last_device_prompt_ms.$facebookAccountKey';

/// [SecretStore] access token for one Facebook identity.
String facebookAccessTokenSecret(String facebookAccountKey) =>
    'provider:access_token:facebook:$facebookAccountKey';
