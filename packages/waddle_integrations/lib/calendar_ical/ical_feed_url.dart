/// Normalizes subscribe URLs for HTTP GET (e.g. `webcal://` → `https://`).
Uri? normalizeIcalFeedUri(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  var candidate = trimmed;
  final lower = candidate.toLowerCase();
  if (lower.startsWith('webcal://')) {
    candidate = 'https://${candidate.substring('webcal://'.length)}';
  } else if (lower.startsWith('webcals://')) {
    candidate = 'https://${candidate.substring('webcals://'.length)}';
  }
  final uri = Uri.tryParse(candidate);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }
  return uri;
}
