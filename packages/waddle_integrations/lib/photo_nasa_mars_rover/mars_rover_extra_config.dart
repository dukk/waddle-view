import 'dart:convert';

const Set<String> kNasaMarsRoverNames = {
  'curiosity',
  'opportunity',
  'spirit',
  'perseverance',
};

class MarsRoverExtraConfig {
  const MarsRoverExtraConfig({
    required this.rovers,
    required this.photosPerCollect,
    required this.maxDaysBack,
    required this.maxPhotos,
    required this.retentionDays,
    required this.category,
  });

  final List<String> rovers;
  final int photosPerCollect;
  final int maxDaysBack;
  final int maxPhotos;
  final int retentionDays;

  /// Default content category when not using per-rover suffix.
  final String category;

  static const _defaults = MarsRoverExtraConfig(
    rovers: ['perseverance', 'curiosity'],
    photosPerCollect: 5,
    maxDaysBack: 7,
    maxPhotos: 200,
    retentionDays: 90,
    category: 'nasa_mars',
  );

  static MarsRoverExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return _defaults;
    }
    try {
      final m = jsonDecode(configJson) as Map<String, dynamic>;
      return MarsRoverExtraConfig(
        rovers: _rovers(m['rovers']),
        photosPerCollect:
            _clamp(m['photosPerCollect'], 1, 20, _defaults.photosPerCollect),
        maxDaysBack: _clamp(m['maxDaysBack'], 1, 30, _defaults.maxDaysBack),
        maxPhotos: _clamp(m['maxPhotos'], 10, 2000, _defaults.maxPhotos),
        retentionDays: _intField(m['retentionDays'], _defaults.retentionDays),
        category: _stringField(m['category'], _defaults.category),
      );
    } on Object {
      return _defaults;
    }
  }

  String categoryForRover(String rover) => '${category}_$rover';
}

List<String> _rovers(Object? raw) {
  if (raw is! List) {
    return MarsRoverExtraConfig._defaults.rovers;
  }
  final out = <String>[];
  for (final item in raw) {
    if (item is! String) {
      continue;
    }
    final name = item.trim().toLowerCase();
    if (kNasaMarsRoverNames.contains(name) && !out.contains(name)) {
      out.add(name);
    }
  }
  return out.isEmpty ? MarsRoverExtraConfig._defaults.rovers : out;
}

int _clamp(Object? v, int min, int max, int fallback) {
  final n = v is int ? v : (v is num ? v.toInt() : fallback);
  if (n < min) {
    return min;
  }
  if (n > max) {
    return max;
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
