/// Scheme, host, and path only — omits query (may contain API keys or tokens).
String safeHttpUriForLog(Uri uri) {
  if (uri.hasAuthority) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    return '${uri.scheme}://${uri.host}$path';
  }
  return uri.hasEmptyPath ? '(relative)' : uri.path;
}
