import 'dart:convert';

const String kDefaultTriviaModel = 'gpt-4o-mini';

const String kDefaultTriviaGlobalPrompt =
    'You write clear, family-friendly multiple-choice trivia. Each item has '
    'one question and exactly four distinct answer choices labeled A–D, with '
    'exactly one correct answer. Favor verifiable facts; avoid trick questions, '
    'slurs, hate, sexual content, or graphic violence.';

const int kDefaultMaxQuestionsPerTwoHours = 20;

const int kDefaultTriviaTwoHourWindowMs = 7200000;

const int kDefaultTriviaRetentionDays = 14;

class TriviaProviderExtraConfig {
  const TriviaProviderExtraConfig({
    required this.questionsPerDay,
    required this.model,
    required this.globalPrompt,
    this.temperature,
    this.maxOutputTokens,
    this.maxQuestionsPerTwoHours = kDefaultMaxQuestionsPerTwoHours,
    this.twoHourWindowMs = kDefaultTriviaTwoHourWindowMs,
    this.questionRetentionDays = kDefaultTriviaRetentionDays,
  });

  final int questionsPerDay;
  final String model;
  final String globalPrompt;
  final double? temperature;
  final int? maxOutputTokens;

  final int maxQuestionsPerTwoHours;
  final int twoHourWindowMs;
  final int questionRetentionDays;

  static TriviaProviderExtraConfig parse(String? extraJson) {
    if (extraJson == null || extraJson.trim().isEmpty) {
      return const TriviaProviderExtraConfig(
        questionsPerDay: 3,
        model: kDefaultTriviaModel,
        globalPrompt: kDefaultTriviaGlobalPrompt,
        maxQuestionsPerTwoHours: kDefaultMaxQuestionsPerTwoHours,
        twoHourWindowMs: kDefaultTriviaTwoHourWindowMs,
        questionRetentionDays: kDefaultTriviaRetentionDays,
      );
    }
    try {
      final dynamic decoded = jsonDecode(extraJson);
      if (decoded is! Map) {
        return const TriviaProviderExtraConfig(
          questionsPerDay: 3,
          model: kDefaultTriviaModel,
          globalPrompt: kDefaultTriviaGlobalPrompt,
          maxQuestionsPerTwoHours: kDefaultMaxQuestionsPerTwoHours,
          twoHourWindowMs: kDefaultTriviaTwoHourWindowMs,
          questionRetentionDays: kDefaultTriviaRetentionDays,
        );
      }
      final m = Map<String, dynamic>.from(decoded);
      final gp =
          m['globalPrompt'] as String? ??
          m['systemPrompt'] as String? ??
          kDefaultTriviaGlobalPrompt;
      return TriviaProviderExtraConfig(
        questionsPerDay: (m['questionsPerDay'] as num?)?.toInt() ?? 3,
        model: m['model'] as String? ?? kDefaultTriviaModel,
        globalPrompt: gp.isEmpty ? kDefaultTriviaGlobalPrompt : gp,
        temperature: (m['temperature'] as num?)?.toDouble(),
        maxOutputTokens: (m['maxOutputTokens'] as num?)?.toInt(),
        maxQuestionsPerTwoHours:
            (m['maxQuestionsPerTwoHours'] as num?)?.toInt() ??
            kDefaultMaxQuestionsPerTwoHours,
        twoHourWindowMs:
            (m['twoHourWindowMs'] as num?)?.toInt() ??
            kDefaultTriviaTwoHourWindowMs,
        questionRetentionDays:
            (m['questionRetentionDays'] as num?)?.toInt() ??
            kDefaultTriviaRetentionDays,
      );
    } on Object {
      return const TriviaProviderExtraConfig(
        questionsPerDay: 3,
        model: kDefaultTriviaModel,
        globalPrompt: kDefaultTriviaGlobalPrompt,
        maxQuestionsPerTwoHours: kDefaultMaxQuestionsPerTwoHours,
        twoHourWindowMs: kDefaultTriviaTwoHourWindowMs,
        questionRetentionDays: kDefaultTriviaRetentionDays,
      );
    }
  }
}
