/// SaaS mode: integrations run in cloud; display consumes SSE feed deltas.
library;

const String kDisplaySaasModeEnv = 'WADDLE_SAAS_MODE';
const String kDisplaySaasApiUrlEnv = 'WADDLE_SAAS_API_URL';
const String kDisplaySaasDisplayIdEnv = 'WADDLE_SAAS_DISPLAY_ID';
const String kDisplaySaasApiKeyEnv = 'WADDLE_SAAS_API_KEY';

bool readSaasModeEnabled(Map<String, String> env) =>
    (env[kDisplaySaasModeEnv] ?? '').trim() == '1';

String? readSaasApiUrl(Map<String, String> env) {
  final v = (env[kDisplaySaasApiUrlEnv] ?? '').trim();
  return v.isEmpty ? null : v;
}

String? readSaasDisplayId(Map<String, String> env) {
  final v = (env[kDisplaySaasDisplayIdEnv] ?? '').trim();
  return v.isEmpty ? null : v;
}

String? readSaasApiKey(Map<String, String> env) {
  final v = (env[kDisplaySaasApiKeyEnv] ?? '').trim();
  return v.isEmpty ? null : v;
}
