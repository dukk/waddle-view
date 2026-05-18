import 'dart:convert';

/// Reads optional `baseUrl` from an integration [configJson] object.
String? integrationBaseUrlFromConfigJson(String? configJson) {
  if (configJson == null || configJson.trim().isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(configJson);
    if (decoded is! Map) {
      return null;
    }
    final raw = decoded['baseUrl'];
    if (raw == null) {
      return null;
    }
    final trimmed = raw.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  } catch (_) {
    return null;
  }
}

/// Merges [baseUrl] into [configJson] when the column value is present and config
/// does not already define a non-empty `baseUrl`.
String? mergeBaseUrlIntoIntegrationConfig(String? configJson, String? baseUrl) {
  final trimmedBase = baseUrl?.trim();
  if (trimmedBase == null || trimmedBase.isEmpty) {
    return configJson;
  }
  Map<String, dynamic> map;
  if (configJson == null || configJson.trim().isEmpty) {
    map = <String, dynamic>{};
  } else {
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return configJson;
      }
      map = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return configJson;
    }
  }
  final existing = map['baseUrl'];
  if (existing != null && existing.toString().trim().isNotEmpty) {
    return configJson;
  }
  map['baseUrl'] = trimmedBase;
  return jsonEncode(map);
}

/// Sets or clears `baseUrl` inside [configJson] (used by operator PATCH / CLI).
String? setBaseUrlInIntegrationConfig(String? configJson, String? baseUrl) {
  final trimmedBase = baseUrl?.trim();
  Map<String, dynamic> map;
  if (configJson == null || configJson.trim().isEmpty) {
    map = <String, dynamic>{};
  } else {
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return configJson;
      }
      map = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return configJson;
    }
  }
  if (trimmedBase == null || trimmedBase.isEmpty) {
    map.remove('baseUrl');
  } else {
    map['baseUrl'] = trimmedBase;
  }
  return jsonEncode(map);
}
