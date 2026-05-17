import 'dart:convert';

class ParsedHomeAssistantState {
  const ParsedHomeAssistantState({
    required this.state,
    required this.attributesJson,
    required this.lastUpdatedMs,
    required this.friendlyName,
  });

  final String state;
  final String attributesJson;
  final int? lastUpdatedMs;
  final String? friendlyName;
}

ParsedHomeAssistantState? parseHomeAssistantStatePayload(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final state = decoded['state'];
    if (state is! String) {
      return null;
    }
    final attributes = decoded['attributes'];
    final attributesJson = jsonEncode(
      attributes is Map ? attributes : <String, dynamic>{},
    );
    String? friendlyName;
    if (attributes is Map) {
      final name = attributes['friendly_name'];
      if (name is String && name.trim().isNotEmpty) {
        friendlyName = name.trim();
      }
    }
    final lastUpdatedMs = _parseHaTimestamp(
      decoded['last_updated'] as String? ?? decoded['last_changed'] as String?,
    );
    return ParsedHomeAssistantState(
      state: state,
      attributesJson: attributesJson,
      lastUpdatedMs: lastUpdatedMs,
      friendlyName: friendlyName,
    );
  } on Object {
    return null;
  }
}

int? _parseHaTimestamp(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    return DateTime.parse(raw).millisecondsSinceEpoch;
  } on Object {
    return null;
  }
}

bool homeAssistantBinarySensorOn(String state) => state.toLowerCase() == 'on';
