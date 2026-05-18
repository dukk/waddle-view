import 'dart:convert';

const int kDefaultHomeAssistantMaxEntitiesPerCollect = 50;
const int kDefaultHomeAssistantRequestTimeoutMs = 15000;

class HomeAssistantEntityDefault {
  const HomeAssistantEntityDefault({
    required this.entityId,
    this.displayName = '',
  });

  final String entityId;
  final String displayName;
}

class HomeAssistantProviderExtraConfig {
  const HomeAssistantProviderExtraConfig({
    required this.maxEntitiesPerCollect,
    required this.requestTimeoutMs,
    required this.defaultEntities,
  });

  final int maxEntitiesPerCollect;
  final int requestTimeoutMs;
  final List<HomeAssistantEntityDefault> defaultEntities;

  static HomeAssistantProviderExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const HomeAssistantProviderExtraConfig(
        maxEntitiesPerCollect: kDefaultHomeAssistantMaxEntitiesPerCollect,
        requestTimeoutMs: kDefaultHomeAssistantRequestTimeoutMs,
        defaultEntities: [],
      );
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return parse(null);
      }
      final m = Map<String, dynamic>.from(decoded);
      final maxRaw = m['maxEntitiesPerCollect'];
      final max = (maxRaw is num && maxRaw.toInt() >= 1)
          ? maxRaw.toInt()
          : kDefaultHomeAssistantMaxEntitiesPerCollect;
      final timeoutRaw = m['requestTimeoutMs'];
      final timeout = (timeoutRaw is num && timeoutRaw.toInt() >= 1000)
          ? timeoutRaw.toInt()
          : kDefaultHomeAssistantRequestTimeoutMs;
      final entities = _parseEntities(m['defaultEntities']);
      return HomeAssistantProviderExtraConfig(
        maxEntitiesPerCollect: max,
        requestTimeoutMs: timeout,
        defaultEntities: List.unmodifiable(entities),
      );
    } on Object {
      return parse(null);
    }
  }

  static List<HomeAssistantEntityDefault> _parseEntities(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final out = <HomeAssistantEntityDefault>[];
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final m = Map<String, dynamic>.from(entry);
      final entityId = (m['entityId'] as String?)?.trim();
      if (entityId == null || entityId.isEmpty) {
        continue;
      }
      final name = (m['displayName'] as String?)?.trim() ?? '';
      out.add(HomeAssistantEntityDefault(
        entityId: entityId,
        displayName: name,
      ));
    }
    return out;
  }
}
