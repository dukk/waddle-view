/// Parsed [web_page] screen `config_json` (no Flutter / WebView types).
class WebPageConfig {
  const WebPageConfig({
    required this.url,
    required this.uri,
    required this.userAgent,
    required this.requestHeaders,
    required this.javascriptEnabled,
    required this.loadTimeoutSeconds,
    required this.autoScroll,
    required this.security,
  });

  final String url;
  final Uri? uri;
  final String? userAgent;
  final Map<String, String> requestHeaders;
  final bool javascriptEnabled;
  final int loadTimeoutSeconds;
  final WebPageAutoScrollConfig autoScroll;
  final WebPageSecurityConfig security;

  String get initialHost => uri?.host.toLowerCase() ?? '';

  bool navigationAllowed(String requestUrl) {
    return security.navigationAllowed(
      requestUrl: requestUrl,
      initialHost: initialHost,
    );
  }
}

class WebPageAutoScrollConfig {
  const WebPageAutoScrollConfig({
    required this.enabled,
    required this.delayMs,
    required this.pixelsPerSecond,
    required this.trailingHoldMs,
  });

  final bool enabled;
  final int delayMs;
  final double pixelsPerSecond;
  final int trailingHoldMs;
}

class WebPageSecurityConfig {
  const WebPageSecurityConfig({
    required this.restrictNavigation,
    required this.allowedHosts,
    required this.blockPopups,
    required this.allowFileAccess,
    required this.mixedContentMode,
    required this.sandboxTokens,
  });

  final bool restrictNavigation;
  final Set<String> allowedHosts;
  final bool blockPopups;
  final bool allowFileAccess;
  final String mixedContentMode;
  final Set<String>? sandboxTokens;

  bool get sandboxRestrictsScripts {
    final tokens = sandboxTokens;
    if (tokens == null) {
      return false;
    }
    return !tokens.contains('allow-scripts');
  }

  bool get sandboxAllowsPopups {
    final tokens = sandboxTokens;
    if (tokens == null) {
      return true;
    }
    return tokens.contains('allow-popups');
  }

  bool navigationAllowed({
    required String requestUrl,
    required String initialHost,
  }) {
    final parsed = Uri.tryParse(requestUrl);
    if (parsed == null) {
      return false;
    }
    if (parsed.scheme == 'file' && !allowFileAccess) {
      return false;
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      if (parsed.scheme == 'about' || parsed.scheme == 'data') {
        return true;
      }
      return allowFileAccess && parsed.scheme == 'file';
    }
    if (!restrictNavigation) {
      return true;
    }
    final host = parsed.host.toLowerCase();
    if (host.isEmpty) {
      return false;
    }
    if (initialHost.isNotEmpty && host == initialHost) {
      return true;
    }
    return allowedHosts.contains(host);
  }
}

WebPageConfig parseWebPageConfig(Map<String, dynamic> raw) {
  final url = (raw['url'] as String?)?.trim() ?? '';
  final uri = url.isEmpty ? null : Uri.tryParse(url);
  final headersRaw = raw['requestHeaders'];
  final headers = <String, String>{};
  if (headersRaw is Map) {
    for (final entry in headersRaw.entries) {
      final k = entry.key.toString().trim();
      if (k.isEmpty) {
        continue;
      }
      final v = entry.value;
      if (v is String) {
        headers[k] = v;
      } else if (v != null) {
        headers[k] = v.toString();
      }
    }
  }

  final securityRaw = raw['security'];
  final securityMap = securityRaw is Map
      ? Map<String, dynamic>.from(securityRaw)
      : const <String, dynamic>{};

  final sandboxRaw = securityMap['sandbox'];
  Set<String>? sandboxTokens;
  if (sandboxRaw is List) {
    sandboxTokens = {
      for (final t in sandboxRaw)
        if (t is String) t.trim().toLowerCase(),
    };
  }

  final allowedHostsRaw = securityMap['allowedHosts'];
  final allowedHosts = <String>{};
  if (allowedHostsRaw is List) {
    for (final h in allowedHostsRaw) {
      if (h is String && h.trim().isNotEmpty) {
        allowedHosts.add(h.trim().toLowerCase());
      }
    }
  }

  final mixed = (securityMap['mixedContentMode'] as String?)?.trim().toLowerCase();
  final mixedContentMode = switch (mixed) {
    'always' || 'compatibility' || 'never' => mixed!,
    _ => 'never',
  };

  final security = WebPageSecurityConfig(
    restrictNavigation: _cfgBool(securityMap, 'restrictNavigation', true),
    allowedHosts: allowedHosts,
    blockPopups: _cfgBool(securityMap, 'blockPopups', true),
    allowFileAccess: _cfgBool(securityMap, 'allowFileAccess', false),
    mixedContentMode: mixedContentMode,
    sandboxTokens: sandboxTokens,
  );

  var javascriptEnabled = _cfgBool(raw, 'javascriptEnabled', true);
  if (security.sandboxRestrictsScripts) {
    javascriptEnabled = false;
  }

  final scrollRaw = raw['autoScroll'];
  final scrollMap = scrollRaw is Map
      ? Map<String, dynamic>.from(scrollRaw)
      : const <String, dynamic>{};

  final autoScroll = WebPageAutoScrollConfig(
    enabled: _cfgBool(scrollMap, 'enabled', false),
    delayMs: _cfgInt(scrollMap, 'delayMs', 2500).clamp(0, 120000),
    pixelsPerSecond: _cfgDouble(scrollMap, 'pixelsPerSecond', 48).clamp(1, 500),
    trailingHoldMs: _cfgInt(scrollMap, 'trailingHoldMs', 1500).clamp(0, 120000),
  );

  return WebPageConfig(
    url: url,
    uri: uri,
    userAgent: (raw['userAgent'] as String?)?.trim().isEmpty ?? true
        ? null
        : (raw['userAgent'] as String).trim(),
    requestHeaders: headers,
    javascriptEnabled: javascriptEnabled,
    loadTimeoutSeconds: _cfgInt(raw, 'loadTimeoutSeconds', 30).clamp(5, 120),
    autoScroll: autoScroll,
    security: security,
  );
}

bool _cfgBool(Map<String, dynamic> c, String key, bool def) {
  final v = c[key];
  if (v is bool) {
    return v;
  }
  if (v is int) {
    return v != 0;
  }
  if (v is String) {
    final n = v.trim().toLowerCase();
    if (n == '1' || n == 'true' || n == 'yes' || n == 'on') {
      return true;
    }
    if (n == '0' || n == 'false' || n == 'no' || n == 'off') {
      return false;
    }
  }
  return def;
}

int _cfgInt(Map<String, dynamic> c, String key, int def) {
  final v = c[key];
  if (v is int) {
    return v;
  }
  if (v is double) {
    return v.round();
  }
  return def;
}

double _cfgDouble(Map<String, dynamic> c, String key, double def) {
  final v = c[key];
  if (v is double) {
    return v;
  }
  if (v is int) {
    return v.toDouble();
  }
  return def;
}

/// Stable cache key for preload / widget handoff.
String webPagePrepareCacheKey({
  required String choiceKey,
  required WebPageConfig config,
}) {
  final headerKeys = config.requestHeaders.keys.toList()..sort();
  final headerDigest = headerKeys
      .map((k) => '$k=${config.requestHeaders[k]}')
      .join('&');
  final sandboxList = config.security.sandboxTokens?.toList();
  if (sandboxList != null) {
    sandboxList.sort();
  }
  return [
    choiceKey,
    config.url,
    config.userAgent ?? '',
    headerDigest,
    config.javascriptEnabled,
    config.loadTimeoutSeconds,
    config.autoScroll.enabled,
    config.security.restrictNavigation,
    config.security.allowedHosts.join(','),
    config.security.blockPopups,
    config.security.allowFileAccess,
    config.security.mixedContentMode,
    sandboxList?.join(',') ?? '',
  ].join('|');
}
