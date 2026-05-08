import 'dart:convert';

const String kDefaultTriviaModel = 'gpt-4o-mini';

const String kDefaultTriviaGlobalPrompt =
    'You write concise, family-friendly multiple-choice trivia. Each item has '
    'one question and exactly four distinct short answer choices labeled A–D, '
    'with exactly one correct answer. Keep the question to at most 90 '
    'characters and each choice to at most 45 characters—no filler words, one '
    'clear fact. Favor verifiable facts; avoid trick questions, slurs, hate, '
    'sexual content, or graphic violence. Do not repeat or closely '
    'paraphrase any question the user lists under "Recent questions to avoid". '
    'Prefer specific, less overused facts rather than the most common textbook '
    'trivia.';

const int kDefaultMaxQuestionPerHour = 20;

/// Default rolling window for [maxQuestionPerHour] (1 hour).
const int kDefaultTriviaRateWindowMs = 3600000;

const int kDefaultTriviaRetentionDays = 15;

const int kDefaultMaxQuestionPerDay = 200;

class TriviaProviderExtraConfig {
  const TriviaProviderExtraConfig({
    required this.maxQuestionPerDay,
    required this.model,
    required this.globalPrompt,
    this.temperature,
    this.maxOutputTokens,
    this.maxQuestionPerHour = kDefaultMaxQuestionPerHour,
    this.twoHourWindowMs = kDefaultTriviaRateWindowMs,
    this.questionRetentionDays = kDefaultTriviaRetentionDays,
  });

  final int maxQuestionPerDay;
  final String model;
  final String globalPrompt;
  final double? temperature;
  final int? maxOutputTokens;

  /// Max trivia items to **request** in a rolling window ([twoHourWindowMs]).
  final int maxQuestionPerHour;

  /// Rolling window length in ms (default 1 hour).
  final int twoHourWindowMs;

  /// Drop trivia older than this many days (by creation timestamp); `<= 0` disables.
  final int questionRetentionDays;

  static int _parseMaxQuestionPerHour(Map<String, dynamic> m) {
    final fromNew = (m['maxQuestionPerHour'] as num?)?.toInt();
    if (fromNew != null) {
      return fromNew;
    }
    final legacy = (m['maxQuestionsPerTwoHours'] as num?)?.toInt();
    if (legacy != null) {
      return legacy;
    }
    return kDefaultMaxQuestionPerHour;
  }

  static int _parseMaxQuestionPerDay(Map<String, dynamic> m) {
    final fromNew = (m['maxQuestionPerDay'] as num?)?.toInt();
    if (fromNew != null) {
      return fromNew;
    }
    final legacy = (m['questionsPerDay'] as num?)?.toInt();
    if (legacy != null) {
      return legacy;
    }
    return kDefaultMaxQuestionPerDay;
  }

  static TriviaProviderExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const TriviaProviderExtraConfig(
        maxQuestionPerDay: kDefaultMaxQuestionPerDay,
        model: kDefaultTriviaModel,
        globalPrompt: kDefaultTriviaGlobalPrompt,
        maxQuestionPerHour: kDefaultMaxQuestionPerHour,
        twoHourWindowMs: kDefaultTriviaRateWindowMs,
        questionRetentionDays: kDefaultTriviaRetentionDays,
      );
    }
    try {
      final dynamic decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return const TriviaProviderExtraConfig(
          maxQuestionPerDay: kDefaultMaxQuestionPerDay,
          model: kDefaultTriviaModel,
          globalPrompt: kDefaultTriviaGlobalPrompt,
          maxQuestionPerHour: kDefaultMaxQuestionPerHour,
          twoHourWindowMs: kDefaultTriviaRateWindowMs,
          questionRetentionDays: kDefaultTriviaRetentionDays,
        );
      }
      final m = Map<String, dynamic>.from(decoded);
      final gp =
          m['globalPrompt'] as String? ??
          m['systemPrompt'] as String? ??
          kDefaultTriviaGlobalPrompt;
      return TriviaProviderExtraConfig(
        maxQuestionPerDay: _parseMaxQuestionPerDay(m),
        model: m['model'] as String? ?? kDefaultTriviaModel,
        globalPrompt: gp.isEmpty ? kDefaultTriviaGlobalPrompt : gp,
        temperature: (m['temperature'] as num?)?.toDouble(),
        maxOutputTokens: (m['maxOutputTokens'] as num?)?.toInt(),
        maxQuestionPerHour: _parseMaxQuestionPerHour(m),
        twoHourWindowMs:
            (m['twoHourWindowMs'] as num?)?.toInt() ??
            kDefaultTriviaRateWindowMs,
        questionRetentionDays:
            (m['questionRetentionDays'] as num?)?.toInt() ??
            kDefaultTriviaRetentionDays,
      );
    } on Object {
      return const TriviaProviderExtraConfig(
        maxQuestionPerDay: kDefaultMaxQuestionPerDay,
        model: kDefaultTriviaModel,
        globalPrompt: kDefaultTriviaGlobalPrompt,
        maxQuestionPerHour: kDefaultMaxQuestionPerHour,
        twoHourWindowMs: kDefaultTriviaRateWindowMs,
        questionRetentionDays: kDefaultTriviaRetentionDays,
      );
    }
  }
}
