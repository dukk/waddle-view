import 'dart:convert';

class ApodExtraConfig {
  const ApodExtraConfig({
    required this.retentionDays,
    required this.category,
    required this.hd,
    required this.backfillDays,
  });

  final int retentionDays;
  final String category;
  final bool hd;
  final int backfillDays;

  static const _defaults = ApodExtraConfig(
    retentionDays: 30,
    category: 'nasa_apod',
    hd: true,
    backfillDays: 0,
  );

  static ApodExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return _defaults;
    }
    try {
      final m = jsonDecode(configJson) as Map<String, dynamic>;
      return ApodExtraConfig(
        retentionDays: _intField(m['retentionDays'], _defaults.retentionDays),
        category: _stringField(m['category'], _defaults.category),
        hd: m['hd'] is bool ? m['hd'] as bool : _defaults.hd,
        backfillDays: _clampBackfill(m['backfillDays']),
      );
    } on Object {
      return _defaults;
    }
  }
}

int _clampBackfill(Object? v) {
  final n = v is int ? v : (v is num ? v.toInt() : 0);
  if (n < 0) {
    return 0;
  }
  if (n > 7) {
    return 7;
  }
  return n;
}

int _intField(Object? v, int fallback) {
  if (v is int) {
    return v;
  }
  if (v is num) {
    return v.toInt();
  }
  return fallback;
}

String _stringField(Object? v, String fallback) {
  if (v is String && v.trim().isNotEmpty) {
    return v.trim();
  }
  return fallback;
}
