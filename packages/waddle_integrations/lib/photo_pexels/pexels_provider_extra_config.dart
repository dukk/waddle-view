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

class PexelsPhotoProviderExtraConfig {
  const PexelsPhotoProviderExtraConfig({
    required this.maxPhotos,
    required this.photosPerHour,
    required this.sources,
  });

  final int maxPhotos;
  final int photosPerHour;
  final List<PexelsSourceSpec> sources;

  static PexelsPhotoProviderExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const PexelsPhotoProviderExtraConfig(
        maxPhotos: 100,
        photosPerHour: 2,
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
      return PexelsPhotoProviderExtraConfig(
        maxPhotos: _positiveInt(m['maxPhotos'], 100),
        photosPerHour: _positiveInt(m['photosPerHour'], 2),
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
