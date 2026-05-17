/// Normalizes `Origin` or `Referer` to `scheme://host:port`.
String? normalizeHttpOrigin(String? raw) {
  if (raw == null) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    final uri = Uri.parse(trimmed);
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    if (uri.host.isEmpty) {
      return null;
    }
    final port = uri.hasPort ? uri.port : _defaultPort(uri.scheme);
    return '${uri.scheme}://${uri.host}:$port';
  } catch (_) {
    return null;
  }
}

int _defaultPort(String scheme) => scheme == 'https' ? 443 : 80;
