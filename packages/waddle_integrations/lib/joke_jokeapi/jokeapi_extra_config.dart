import 'dart:convert';

const int kDefaultJokeApiJokesPerPoll = 5;
const int kDefaultJokeApiRetentionDays = 14;

const Set<String> kJokeApiBlacklistFlags = {
  'nsfw',
  'religious',
  'political',
  'racist',
  'sexist',
  'explicit',
};

class JokeApiExtraConfig {
  const JokeApiExtraConfig({
    this.jokesPerPoll = kDefaultJokeApiJokesPerPoll,
    this.categoryMap = const <String, String>{},
    this.blacklistFlags = const <String>[],
    this.contains,
    this.jokeRetentionDays = kDefaultJokeApiRetentionDays,
  });

  final int jokesPerPoll;
  final Map<String, String> categoryMap;
  final List<String> blacklistFlags;
  final String? contains;
  final int jokeRetentionDays;

  static JokeApiExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const JokeApiExtraConfig();
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return const JokeApiExtraConfig();
      }
      final m = Map<String, dynamic>.from(decoded);
      final jokesPerPoll =
          ((m['jokesPerPoll'] as num?)?.toInt() ?? kDefaultJokeApiJokesPerPoll)
              .clamp(1, 10);
      final retentionDays =
          (m['jokeRetentionDays'] as num?)?.toInt() ??
              kDefaultJokeApiRetentionDays;
      final contains = _parseContains(m['contains']);
      return JokeApiExtraConfig(
        jokesPerPoll: jokesPerPoll,
        categoryMap: _parseCategoryMap(m['categoryMap']),
        blacklistFlags: _parseBlacklistFlags(m['blacklistFlags']),
        contains: contains,
        jokeRetentionDays: retentionDays,
      );
    } on Object {
      return const JokeApiExtraConfig();
    }
  }

  static String? _parseContains(Object? raw) {
    final value = (raw as String?)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static Map<String, String> _parseCategoryMap(Object? raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }
    final out = <String, String>{};
    raw.forEach((key, value) {
      if (key is! String) {
        return;
      }
      final categoryId = key.trim();
      final apiCategory = (value as String?)?.trim() ?? '';
      if (categoryId.isEmpty || apiCategory.isEmpty) {
        return;
      }
      out[categoryId] = apiCategory;
    });
    return Map.unmodifiable(out);
  }

  static List<String> _parseBlacklistFlags(Object? raw) {
    if (raw is! List) {
      return const <String>[];
    }
    final out = <String>[];
    for (final item in raw) {
      final flag = (item as String?)?.trim().toLowerCase();
      if (flag == null || flag.isEmpty) {
        continue;
      }
      if (!kJokeApiBlacklistFlags.contains(flag)) {
        continue;
      }
      if (!out.contains(flag)) {
        out.add(flag);
      }
    }
    return List.unmodifiable(out);
  }
}
