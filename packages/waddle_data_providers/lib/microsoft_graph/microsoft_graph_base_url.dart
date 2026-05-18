/// Default Microsoft Graph REST API root used by Graph-backed collectors.
const String kDefaultGraphBaseUrl = 'https://graph.microsoft.com/v1.0';

/// Normalizes integration [baseUrl] for Graph REST calls.
String normalizeMicrosoftGraphBaseUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return kDefaultGraphBaseUrl;
  }
  return raw.trim().replaceAll(RegExp(r'/$'), '');
}
