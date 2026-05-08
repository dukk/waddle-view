import 'dart:convert';

/// One folder under the signed-in user's OneDrive (delegated `me` drive).
class OneDriveMediaSourceSpec {
  const OneDriveMediaSourceSpec({
    required this.path,
    required this.kind,
    required this.category,
    required this.maxFiles,
    this.perPollLimit,
  });

  /// Root-relative path, e.g. `/Pictures/Family` or `Pictures/Family`.
  final String path;

  /// `photo`, `video`, or `both` (supported image + video MIME types).
  final String kind;

  /// Slug matching [ContentCategories.id] for curator / slide `categoryId`.
  final String category;

  /// Retention cap: oldest OneDrive rows in this category are pruned after sync.
  final int maxFiles;

  /// Max new downloads per collect for this source; `null` means [maxFiles].
  final int? perPollLimit;

  int get effectivePerPollLimit => perPollLimit ?? maxFiles;

  static OneDriveMediaSourceSpec? parse(Map<String, dynamic> m) {
    final pathRaw = m['path'] ?? m['folder'];
    if (pathRaw != null && pathRaw is! String) {
      return null;
    }
    final path = pathRaw is String ? pathRaw.trim() : '';
    final kindRaw = m['kind'] ?? m['type'];
    if (kindRaw is! String || kindRaw.trim().isEmpty) {
      return null;
    }
    final kind = kindRaw.trim().toLowerCase();
    if (kind != 'photo' && kind != 'video' && kind != 'both') {
      return null;
    }
    final cat = m['category'];
    if (cat is! String || cat.trim().isEmpty) {
      return null;
    }
    final maxFiles = _positiveInt(m['maxFiles'], 50);
    final perPoll = _optionalPositiveInt(m['perPollLimit']);
    return OneDriveMediaSourceSpec(
      path: path,
      kind: kind,
      category: cat.trim(),
      maxFiles: maxFiles,
      perPollLimit: perPoll,
    );
  }
}

class OneDriveMediaAccountConfig {
  const OneDriveMediaAccountConfig({
    required this.graphAccountKey,
    required this.sources,
  });

  final String graphAccountKey;
  final List<OneDriveMediaSourceSpec> sources;

  static OneDriveMediaAccountConfig? parse(Map<String, dynamic> m) {
    final key = m['graphAccountKey'];
    if (key is! String || key.trim().isEmpty) {
      return null;
    }
    final sources = <OneDriveMediaSourceSpec>[];
    final raw = m['sources'];
    if (raw is List<dynamic>) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final s = OneDriveMediaSourceSpec.parse(e);
          if (s != null) {
            sources.add(s);
          }
        }
      }
    }
    return OneDriveMediaAccountConfig(
      graphAccountKey: key.trim(),
      sources: sources,
    );
  }
}

class OneDriveMediaExtraConfig {
  const OneDriveMediaExtraConfig({
    required this.accounts,
    required this.globalPerPollLimit,
  });

  final List<OneDriveMediaAccountConfig> accounts;

  /// Soft cap on new file downloads per engine cycle across all sources.
  final int globalPerPollLimit;

  static OneDriveMediaExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const OneDriveMediaExtraConfig(
        accounts: [],
        globalPerPollLimit: 50,
      );
    }
    try {
      final m = jsonDecode(configJson) as Map<String, dynamic>;
      final accounts = <OneDriveMediaAccountConfig>[];
      final rawAccounts = m['accounts'];
      if (rawAccounts is List<dynamic>) {
        for (final e in rawAccounts) {
          if (e is Map<String, dynamic>) {
            final a = OneDriveMediaAccountConfig.parse(e);
            if (a != null) {
              accounts.add(a);
            }
          }
        }
      }
      return OneDriveMediaExtraConfig(
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
