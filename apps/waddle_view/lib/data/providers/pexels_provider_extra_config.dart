import 'dart:convert';

class PexelsSourceSpec {
  const PexelsSourceSpec({required this.query, required this.category});

  final String query;
  final String category;

  static PexelsSourceSpec? parse(Map<String, dynamic> m) {
    final q = m['query'];
    final c = m['category'];
    if (q is! String || q.trim().isEmpty) {
      return null;
    }
    if (c is! String || c.trim().isEmpty) {
      return null;
    }
    return PexelsSourceSpec(query: q.trim(), category: c.trim());
  }
}

class PexelsProviderExtraConfig {
  const PexelsProviderExtraConfig({
    required this.maxPhotos,
    required this.maxVideos,
    required this.photosPerHour,
    required this.videosPerHour,
    required this.minVideoSeconds,
    required this.maxVideoSeconds,
    required this.sources,
  });

  final int maxPhotos;
  final int maxVideos;
  final int photosPerHour;
  final int videosPerHour;
  final int minVideoSeconds;
  final int maxVideoSeconds;
  final List<PexelsSourceSpec> sources;

  static PexelsProviderExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const PexelsProviderExtraConfig(
        maxPhotos: 100,
        maxVideos: 100,
        photosPerHour: 2,
        videosPerHour: 2,
        minVideoSeconds: 11,
        maxVideoSeconds: 29,
        sources: [],
      );
    }
    try {
      final m = jsonDecode(configJson) as Map<String, dynamic>;
      final sourcesRaw = m['sources'];
      final sources = <PexelsSourceSpec>[];
      if (sourcesRaw is List<dynamic>) {
        for (final e in sourcesRaw) {
          if (e is Map<String, dynamic>) {
            final s = PexelsSourceSpec.parse(e);
            if (s != null) {
              sources.add(s);
            }
          }
        }
      }
      return PexelsProviderExtraConfig(
        maxPhotos: _positiveInt(m['maxPhotos'], 100),
        maxVideos: _positiveInt(m['maxVideos'], 100),
        photosPerHour: _positiveInt(m['photosPerHour'], 2),
        videosPerHour: _positiveInt(m['videosPerHour'], 2),
        minVideoSeconds: _positiveInt(m['minVideoSeconds'], 11),
        maxVideoSeconds: _positiveInt(m['maxVideoSeconds'], 29),
        sources: sources,
      );
    } on Object {
      return parse(null);
    }
  }
}

int _positiveInt(Object? v, int def) {
  if (v is int) {
    return v < 1 ? def : v;
  }
  if (v is double) {
    final r = v.round();
    return r < 1 ? def : r;
  }
  return def;
}
