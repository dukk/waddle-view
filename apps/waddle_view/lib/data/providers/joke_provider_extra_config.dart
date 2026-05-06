import 'dart:convert';

const String kDefaultJokeModel = 'gpt-4o-mini';

const String kDefaultJokeGlobalPrompt =
    'You write original, family-friendly jokes. Each joke has a short setup '
    'and a punchline. Avoid slurs, hate, sexual content, or graphic violence.';

const int kDefaultMaxJokesPerTwoHours = 20;

const int kDefaultTwoHourWindowMs = 7200000;

/// Delete jokes whose stored creation time is older than this many whole days.
const int kDefaultJokeRetentionDays = 14;

class JokeProviderExtraConfig {
  const JokeProviderExtraConfig({
    required this.jokesPerDay,
    required this.model,
    required this.globalPrompt,
    this.temperature,
    this.maxOutputTokens,
    this.maxJokesPerTwoHours = kDefaultMaxJokesPerTwoHours,
    this.twoHourWindowMs = kDefaultTwoHourWindowMs,
    this.jokeRetentionDays = kDefaultJokeRetentionDays,
  });

  final int jokesPerDay;
  final String model;
  final String globalPrompt;
  final double? temperature;
  final int? maxOutputTokens;

  /// Max jokes to **request** from OpenAI in a rolling window ([twoHourWindowMs]).
  final int maxJokesPerTwoHours;

  /// Rolling window length in ms (default 2 hours).
  final int twoHourWindowMs;

  /// Drop jokes older than this many days (by creation timestamp); `<= 0` disables.
  final int jokeRetentionDays;

  static JokeProviderExtraConfig parse(String? extraJson) {
    if (extraJson == null || extraJson.trim().isEmpty) {
      return const JokeProviderExtraConfig(
        jokesPerDay: 3,
        model: kDefaultJokeModel,
        globalPrompt: kDefaultJokeGlobalPrompt,
        maxJokesPerTwoHours: kDefaultMaxJokesPerTwoHours,
        twoHourWindowMs: kDefaultTwoHourWindowMs,
        jokeRetentionDays: kDefaultJokeRetentionDays,
      );
    }
    try {
      final dynamic decoded = jsonDecode(extraJson);
      if (decoded is! Map) {
        return const JokeProviderExtraConfig(
          jokesPerDay: 3,
          model: kDefaultJokeModel,
          globalPrompt: kDefaultJokeGlobalPrompt,
          maxJokesPerTwoHours: kDefaultMaxJokesPerTwoHours,
          twoHourWindowMs: kDefaultTwoHourWindowMs,
          jokeRetentionDays: kDefaultJokeRetentionDays,
        );
      }
      final m = Map<String, dynamic>.from(decoded);
      final gp =
          m['globalPrompt'] as String? ??
          m['systemPrompt'] as String? ??
          kDefaultJokeGlobalPrompt;
      return JokeProviderExtraConfig(
        jokesPerDay: (m['jokesPerDay'] as num?)?.toInt() ?? 3,
        model: m['model'] as String? ?? kDefaultJokeModel,
        globalPrompt: gp.isEmpty ? kDefaultJokeGlobalPrompt : gp,
        temperature: (m['temperature'] as num?)?.toDouble(),
        maxOutputTokens: (m['maxOutputTokens'] as num?)?.toInt(),
        maxJokesPerTwoHours:
            (m['maxJokesPerTwoHours'] as num?)?.toInt() ??
            kDefaultMaxJokesPerTwoHours,
        twoHourWindowMs:
            (m['twoHourWindowMs'] as num?)?.toInt() ?? kDefaultTwoHourWindowMs,
        jokeRetentionDays:
            (m['jokeRetentionDays'] as num?)?.toInt() ??
            kDefaultJokeRetentionDays,
      );
    } on Object {
      return const JokeProviderExtraConfig(
        jokesPerDay: 3,
        model: kDefaultJokeModel,
        globalPrompt: kDefaultJokeGlobalPrompt,
        maxJokesPerTwoHours: kDefaultMaxJokesPerTwoHours,
        twoHourWindowMs: kDefaultTwoHourWindowMs,
        jokeRetentionDays: kDefaultJokeRetentionDays,
      );
    }
  }
}
