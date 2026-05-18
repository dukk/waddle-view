import 'dart:convert';

class FlickrMediaExtraConfig {
  const FlickrMediaExtraConfig({
    required this.groupIds,
    required this.category,
    required this.perPollLimit,
    required this.sort,
  });

  final List<String> groupIds;
  final String category;
  final int perPollLimit;
  final String sort;

  static FlickrMediaExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const FlickrMediaExtraConfig(
        groupIds: [],
        category: 'flickr',
        perPollLimit: 20,
        sort: 'date-posted-desc',
      );
    }
    try {
      final m = jsonDecode(configJson) as Map<String, dynamic>;
      final groups = <String>[];
      final rawGroups = m['groupIds'];
      if (rawGroups is List<dynamic>) {
        for (final g in rawGroups) {
          if (g is String && g.trim().isNotEmpty) {
            groups.add(g.trim());
          }
        }
      }
      final category = (m['category'] is String && (m['category'] as String).trim().isNotEmpty)
          ? (m['category'] as String).trim()
          : 'flickr';
      final sort = (m['sort'] is String && (m['sort'] as String).trim().isNotEmpty)
          ? (m['sort'] as String).trim()
          : 'date-posted-desc';
      return FlickrMediaExtraConfig(
        groupIds: groups,
        category: category,
        perPollLimit: _positiveInt(m['perPollLimit'], 20),
        sort: sort,
      );
    } on Object {
      return parse(null);
    }
  }
}

int _positiveInt(Object? v, int fallback) {
  if (v is int && v > 0) {
    return v;
  }
  if (v is num && v.toInt() > 0) {
    return v.toInt();
  }
  return fallback;
}
