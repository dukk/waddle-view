import 'dart:convert';

const int kDefaultOpenTdbAmount = 10;
const int kDefaultOpenTdbRetentionDays = 15;
const int kDefaultOpenTdbMaxQuestionChars = 90;
const int kDefaultOpenTdbMaxOptionChars = 45;

class OpenTdbTriviaExtraConfig {
  const OpenTdbTriviaExtraConfig({
    this.amount = kDefaultOpenTdbAmount,
    this.difficulty,
    this.questionType,
    this.categoryMap = const <String, int>{},
    this.questionRetentionDays = kDefaultOpenTdbRetentionDays,
    this.maxQuestionChars = kDefaultOpenTdbMaxQuestionChars,
    this.maxOptionChars = kDefaultOpenTdbMaxOptionChars,
  });

  final int amount;
  final String? difficulty;
  final String? questionType;
  final Map<String, int> categoryMap;
  final int questionRetentionDays;
  final int maxQuestionChars;
  final int maxOptionChars;

  static OpenTdbTriviaExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const OpenTdbTriviaExtraConfig();
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return const OpenTdbTriviaExtraConfig();
      }
      final m = Map<String, dynamic>.from(decoded);
      final amount = ((m['amount'] as num?)?.toInt() ?? kDefaultOpenTdbAmount)
          .clamp(1, 50);
      final retentionDays =
          (m['questionRetentionDays'] as num?)?.toInt() ??
              kDefaultOpenTdbRetentionDays;
      final maxQuestionChars =
          ((m['maxQuestionChars'] as num?)?.toInt() ??
                  kDefaultOpenTdbMaxQuestionChars)
              .clamp(20, 500);
      final maxOptionChars =
          ((m['maxOptionChars'] as num?)?.toInt() ??
                  kDefaultOpenTdbMaxOptionChars)
              .clamp(10, 200);
      return OpenTdbTriviaExtraConfig(
        amount: amount,
        difficulty: _normalizeEnum(
          m['difficulty'],
          const {'easy', 'medium', 'hard'},
        ),
        questionType: _normalizeEnum(
          m['questionType'],
          const {'multiple', 'boolean'},
        ),
        categoryMap: _parseCategoryMap(m['categoryMap']),
        questionRetentionDays: retentionDays,
        maxQuestionChars: maxQuestionChars,
        maxOptionChars: maxOptionChars,
      );
    } on Object {
      return const OpenTdbTriviaExtraConfig();
    }
  }

  static String? _normalizeEnum(Object? raw, Set<String> allowed) {
    final value = (raw as String?)?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return null;
    }
    if (!allowed.contains(value)) {
      return null;
    }
    return value;
  }

  static Map<String, int> _parseCategoryMap(Object? raw) {
    if (raw is! Map) {
      return const <String, int>{};
    }
    final out = <String, int>{};
    raw.forEach((key, value) {
      if (key is! String) {
        return;
      }
      final categoryId = key.trim();
      final number = (value is num) ? value.toInt() : int.tryParse('$value');
      if (categoryId.isEmpty || number == null || number < 1) {
        return;
      }
      out[categoryId] = number;
    });
    return Map.unmodifiable(out);
  }
}
