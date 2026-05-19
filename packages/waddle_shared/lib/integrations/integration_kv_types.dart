/// [IntegrationsKeyValue.valueType] for epoch-millisecond counters and gates.
const String kIntegrationKvTypeIntMs = 'int_ms';

/// Plain string payload.
const String kIntegrationKvTypeString = 'string';

/// JSON document stored as a string (general_openai prompt results).
const String kIntegrationKvTypeJson = 'json';

/// Microsoft Graph `@odata.deltaLink` URL.
const String kIntegrationKvTypeDeltaLink = 'delta_link';

/// Logical [IntegrationsKeyValue.key] for per-integration poll gate.
const String kIntegrationLastCollectKey = 'last_collect_ms';

/// Account-scoped OAuth access token expiry (epoch ms).
const String kIntegrationAccessTokenExpiresAtKey = 'access_token_expires_at_ms';

/// Account-scoped device-code prompt throttle (epoch ms).
const String kIntegrationLastDevicePromptKey = 'last_device_prompt_ms';

/// Logical key prefix for OneDrive delta links; suffix is path hash tag.
const String kIntegrationDeltaLinkKeyPrefix = 'delta_link.';

/// Builds `delta_link.{pathTag}` for [IntegrationsKeyValue.key].
String integrationDeltaLinkKey(String pathTag) =>
    '$kIntegrationDeltaLinkKeyPrefix$pathTag';
