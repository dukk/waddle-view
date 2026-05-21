import 'dart:convert';

class QuoterismExtraConfig {
  const QuoterismExtraConfig({
    required this.pageLimit,
    required this.pagesPerCollect,
    required this.maxStoredQuotes,
    required this.retentionDays,
    required this.fetchAuthorImages,
  });

  final int pageLimit;
  final int pagesPerCollect;
  final int maxStoredQuotes;
  final int retentionDays;
  final bool fetchAuthorImages;

  static QuoterismExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const QuoterismExtraConfig(
        pageLimit: 20,
        pagesPerCollect: 1,
        maxStoredQuotes: 500,
        retentionDays: 90,
        fetchAuthorImages: true,
      );
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return const QuoterismExtraConfig(
          pageLimit: 20,
          pagesPerCollect: 1,
          maxStoredQuotes: 500,
          retentionDays: 90,
          fetchAuthorImages: true,
        );
      }
      return QuoterismExtraConfig(
        pageLimit: _clampInt(decoded['pageLimit'], 1, 100, 20),
        pagesPerCollect: _clampInt(decoded['pagesPerCollect'], 1, 5, 1),
        maxStoredQuotes: _clampInt(decoded['maxStoredQuotes'], 10, 5000, 500),
        retentionDays: _clampInt(decoded['retentionDays'], 0, 3650, 90),
        fetchAuthorImages: decoded['fetchAuthorImages'] != false,
      );
    } on Object {
      return const QuoterismExtraConfig(
        pageLimit: 20,
        pagesPerCollect: 1,
        maxStoredQuotes: 500,
        retentionDays: 90,
        fetchAuthorImages: true,
      );
    }
  }
}

int _clampInt(dynamic value, int min, int max, int fallback) {
  if (value is int) {
    return value.clamp(min, max);
  }
  if (value is double) {
    return value.round().clamp(min, max);
  }
  return fallback;
}
