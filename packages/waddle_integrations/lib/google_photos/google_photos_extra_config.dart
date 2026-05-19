import 'dart:convert';

/// One album source backed by a Google Photos Picker selection.
class GooglePhotosSourceSpec {
  const GooglePhotosSourceSpec({
    required this.sourceId,
    required this.albumLabel,
    required this.albumSearchHint,
    required this.category,
    required this.maxFiles,
    this.perPollLimit,
    this.mediaItemIds = const [],
    this.pickerSessionId,
    this.lastPickedAtMs,
  });

  final String sourceId;
  final String albumLabel;
  final String albumSearchHint;
  final String category;
  final int maxFiles;
  final int? perPollLimit;
  final List<String> mediaItemIds;
  final String? pickerSessionId;
  final int? lastPickedAtMs;

  int get effectivePerPollLimit => perPollLimit ?? maxFiles;

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'albumLabel': albumLabel,
        'albumSearchHint': albumSearchHint,
        'category': category,
        'maxFiles': maxFiles,
        if (perPollLimit != null) 'perPollLimit': perPollLimit,
        'mediaItemIds': mediaItemIds,
        if (pickerSessionId != null && pickerSessionId!.isNotEmpty)
          'pickerSessionId': pickerSessionId,
        if (lastPickedAtMs != null) 'lastPickedAtMs': lastPickedAtMs,
      };

  static GooglePhotosSourceSpec? parse(Map<String, dynamic> m) {
    final sourceId = m['sourceId'];
    if (sourceId is! String || sourceId.trim().isEmpty) {
      return null;
    }
    final albumLabel = m['albumLabel'];
    final albumSearchHint = m['albumSearchHint'];
    final cat = m['category'];
    if (cat is! String || cat.trim().isEmpty) {
      return null;
    }
    final ids = <String>[];
    final rawIds = m['mediaItemIds'];
    if (rawIds is List<dynamic>) {
      for (final e in rawIds) {
        if (e is String && e.trim().isNotEmpty) {
          ids.add(e.trim());
        }
      }
    }
    final session = m['pickerSessionId'];
    final lastPicked = m['lastPickedAtMs'];
    return GooglePhotosSourceSpec(
      sourceId: sourceId.trim(),
      albumLabel: albumLabel is String ? albumLabel.trim() : '',
      albumSearchHint: albumSearchHint is String ? albumSearchHint.trim() : '',
      category: cat.trim(),
      maxFiles: _positiveInt(m['maxFiles'], 50),
      perPollLimit: _optionalPositiveInt(m['perPollLimit']),
      mediaItemIds: ids,
      pickerSessionId: session is String && session.trim().isNotEmpty
          ? session.trim()
          : null,
      lastPickedAtMs: lastPicked is int
          ? lastPicked
          : (lastPicked is num ? lastPicked.toInt() : null),
    );
  }
}

class GooglePhotosAccountConfig {
  const GooglePhotosAccountConfig({
    required this.googleAccountKey,
    required this.sources,
  });

  final String googleAccountKey;
  final List<GooglePhotosSourceSpec> sources;

  static GooglePhotosAccountConfig? parse(Map<String, dynamic> m) {
    final key = m['googleAccountKey'];
    if (key is! String || key.trim().isEmpty) {
      return null;
    }
    final sources = <GooglePhotosSourceSpec>[];
    final raw = m['sources'];
    if (raw is List<dynamic>) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final s = GooglePhotosSourceSpec.parse(e);
          if (s != null) {
            sources.add(s);
          }
        }
      }
    }
    return GooglePhotosAccountConfig(
      googleAccountKey: key.trim(),
      sources: sources,
    );
  }
}

class GooglePhotosExtraConfig {
  const GooglePhotosExtraConfig({
    required this.accounts,
    required this.globalPerPollLimit,
  });

  final List<GooglePhotosAccountConfig> accounts;
  final int globalPerPollLimit;

  static GooglePhotosExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const GooglePhotosExtraConfig(
        accounts: [],
        globalPerPollLimit: 50,
      );
    }
    try {
      final m = jsonDecode(configJson) as Map<String, dynamic>;
      final accounts = <GooglePhotosAccountConfig>[];
      final rawAccounts = m['accounts'];
      if (rawAccounts is List<dynamic>) {
        for (final e in rawAccounts) {
          if (e is Map<String, dynamic>) {
            final a = GooglePhotosAccountConfig.parse(e);
            if (a != null) {
              accounts.add(a);
            }
          }
        }
      }
      return GooglePhotosExtraConfig(
        accounts: accounts,
        globalPerPollLimit: _positiveInt(m['globalPerPollLimit'], 50),
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

int? _optionalPositiveInt(Object? v) {
  if (v == null) {
    return null;
  }
  if (v is int && v > 0) {
    return v;
  }
  if (v is num && v.toInt() > 0) {
    return v.toInt();
  }
  return null;
}
