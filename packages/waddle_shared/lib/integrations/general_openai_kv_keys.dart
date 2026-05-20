/// Key prefix for [general_openai] integration KV rows (`prompt.{id}.*`).
const String kGeneralOpenAiPromptKeyPrefix = 'prompt.';

/// Latest collected value for a prompt (`prompt.{promptId}.latest`).
String generalOpenAiPromptLatestKey(String promptId) =>
    '$kGeneralOpenAiPromptKeyPrefix${promptId.trim()}.latest';

/// Immutable history entry (`prompt.{promptId}.history.{collectedAtMs}`).
String generalOpenAiPromptHistoryKey(String promptId, int collectedAtMs) =>
    '$kGeneralOpenAiPromptKeyPrefix${promptId.trim()}.history.$collectedAtMs';

/// Per-prompt poll gate (`prompt.{promptId}.last_collect_ms`).
String generalOpenAiPromptLastCollectKey(String promptId) =>
    '$kGeneralOpenAiPromptKeyPrefix${promptId.trim()}.last_collect_ms';

/// Last collect failure message (`prompt.{promptId}.last_error`).
String generalOpenAiPromptLastErrorKey(String promptId) =>
    '$kGeneralOpenAiPromptKeyPrefix${promptId.trim()}.last_error';

/// Prefix for listing/deleting history rows for one prompt.
String generalOpenAiPromptHistoryPrefix(String promptId) =>
    '$kGeneralOpenAiPromptKeyPrefix${promptId.trim()}.history.';

/// Prefix for all prompt-scoped keys on an integration.
String generalOpenAiPromptKeyPrefixForIntegration() =>
    kGeneralOpenAiPromptKeyPrefix;

/// Whether [key] is a general_openai per-prompt poll gate.
bool isGeneralOpenAiPromptLastCollectKey(String key) =>
    key.startsWith(kGeneralOpenAiPromptKeyPrefix) &&
    key.endsWith('.last_collect_ms');
