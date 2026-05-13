import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../../debug/app_debug_log.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../data_provider.dart';
import '../../data_write_context.dart';
import '../trivia/trivia_category_eligibility.dart';
import '../trivia/trivia_id.dart';
import 'opentdb_trivia_extra_config.dart';

const String kOpenTdbTriviaProviderId = 'opentdb_trivia';
const String kDefaultOpenTdbBaseUrl = 'https://opentdb.com/api.php';

class OpenTdbTriviaDataProvider implements IDataProvider {
  OpenTdbTriviaDataProvider({
    http.Client? httpClient,
    DateTime Function()? now,
    Random? random,
  })  : _http = httpClient ?? http.Client(),
        _now = now ?? DateTime.now,
        _random = random ?? Random();

  final http.Client _http;
  final DateTime Function() _now;
  final Random _random;

  @override
  String get id => kOpenTdbTriviaProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting = await (ctx.db.select(ctx.db.providerSettings)
          ..where((t) => t.id.equals(kOpenTdbTriviaProviderId)))
        .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      AppDebugLog.provider('opentdb_trivia: skip (disabled)');
      return;
    }
    final config = await ctx.resolveConfig(kOpenTdbTriviaProviderId);
    final extra = OpenTdbTriviaExtraConfig.parse(config.configJson);
    final now = _now();
    final nowMs = now.millisecondsSinceEpoch;

    final purged = await _purgeTriviaPastRetention(
      ctx,
      nowMs: nowMs,
      retentionDays: extra.questionRetentionDays,
    );
    if (purged > 0) {
      AppDebugLog.provider('opentdb_trivia: purged $purged old question(s)');
    }

    final categories = await ctx.db.select(ctx.db.triviaCategories).get();
    final eligible = categories
        .where((c) => isTriviaCategoryEligibleOn(c, now))
        .toList();
    if (eligible.isEmpty) {
      AppDebugLog.provider('opentdb_trivia: no eligible categories');
      return;
    }
    final picked = eligible[_random.nextInt(eligible.length)];
    final query = <String, String>{'amount': '${extra.amount}'};
    final mapped = extra.categoryMap[picked.id];
    if (mapped != null) {
      query['category'] = '$mapped';
    }
    if (extra.difficulty != null) {
      query['difficulty'] = extra.difficulty!;
    }
    if (extra.questionType != null) {
      query['type'] = extra.questionType!;
    }

    final endpoint =
        (config.baseUrl == null || config.baseUrl!.trim().isEmpty)
        ? kDefaultOpenTdbBaseUrl
        : config.baseUrl!.trim();
    final uri = Uri.parse(endpoint).replace(queryParameters: query);
    AppDebugLog.provider('opentdb_trivia: GET ${AppDebugLog.safeHttpUri(uri)}');

    try {
      final res = await _http.get(uri);
      if (res.statusCode != 200) {
        AppDebugLog.provider(
          'opentdb_trivia: status=${res.statusCode} bodyLen=${res.body.length}',
        );
        return;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final responseCode = (decoded['response_code'] as num?)?.toInt() ?? -1;
      if (responseCode != 0) {
        AppDebugLog.provider('opentdb_trivia: response_code=$responseCode');
        return;
      }
      final results = decoded['results'];
      if (results is! List) {
        return;
      }
      final existingByCategory = await _normalizedQuestionsByCategory(
        ctx,
        categoryIds: eligible.map((e) => e.id),
      );
      var inserted = 0;
      final createdAt = _now();
      for (final row in results) {
        if (row is! Map) {
          continue;
        }
        final m = Map<String, dynamic>.from(row);
        final mappedQuestion = _mapQuestion(
          m,
          fallbackCategoryId: picked.id,
          maxQuestionChars: extra.maxQuestionChars,
          maxOptionChars: extra.maxOptionChars,
        );
        if (mappedQuestion == null) {
          continue;
        }
        if (!eligible.any((e) => e.id == mappedQuestion.categoryId)) {
          continue;
        }
        final normalizedQuestion = mappedQuestion.question.toLowerCase();
        final existing = existingByCategory.putIfAbsent(
          mappedQuestion.categoryId,
          () => <String>{},
        );
        if (existing.contains(normalizedQuestion)) {
          continue;
        }
        final id = triviaStableId(
          mappedQuestion.categoryId,
          mappedQuestion.question,
          mappedQuestion.optionA,
          mappedQuestion.optionB,
          mappedQuestion.optionC,
          mappedQuestion.optionD,
          mappedQuestion.correctOption,
        );
        await ctx.db.into(ctx.db.triviaQuestions).insert(
              TriviaQuestionsCompanion.insert(
                id: id,
                categoryId: mappedQuestion.categoryId,
                question: mappedQuestion.question,
                optionA: mappedQuestion.optionA,
                optionB: mappedQuestion.optionB,
                optionC: mappedQuestion.optionC,
                optionD: mappedQuestion.optionD,
                correctOption: mappedQuestion.correctOption,
                createdAtMs: createdAt,
              ),
              onConflict: DoUpdate(
                (old) => TriviaQuestionsCompanion(
                  categoryId: Value(mappedQuestion.categoryId),
                  question: Value(mappedQuestion.question),
                  optionA: Value(mappedQuestion.optionA),
                  optionB: Value(mappedQuestion.optionB),
                  optionC: Value(mappedQuestion.optionC),
                  optionD: Value(mappedQuestion.optionD),
                  correctOption: Value(mappedQuestion.correctOption),
                  createdAtMs: Value(createdAt),
                ),
              ),
            );
        existing.add(normalizedQuestion);
        inserted++;
      }
      AppDebugLog.provider(
        'opentdb_trivia: upserted $inserted question(s) from ${results.length} item(s)',
      );
    } on Object catch (e, st) {
      AppDebugLog.providerFail('opentdb_trivia: collect', e, st);
    }
  }

  Future<Map<String, Set<String>>> _normalizedQuestionsByCategory(
    DataWriteContext ctx, {
    required Iterable<String> categoryIds,
  }) async {
    final ids = categoryIds.toList();
    if (ids.isEmpty) {
      return {};
    }
    final rows = await (ctx.db.select(ctx.db.triviaQuestions)
          ..where((t) => t.categoryId.isIn(ids)))
        .get();
    final out = <String, Set<String>>{};
    for (final r in rows) {
      final norm = r.question.trim().toLowerCase();
      if (norm.isEmpty) {
        continue;
      }
      out.putIfAbsent(r.categoryId, () => <String>{}).add(norm);
    }
    return out;
  }

  Future<int> _purgeTriviaPastRetention(
    DataWriteContext ctx, {
    required int nowMs,
    required int retentionDays,
  }) async {
    if (retentionDays <= 0) {
      return 0;
    }
    final cutoff = DateTime.fromMillisecondsSinceEpoch(
      nowMs - Duration(days: retentionDays).inMilliseconds,
    );
    return (ctx.db.delete(ctx.db.triviaQuestions)
          ..where((t) => t.createdAtMs.isSmallerThanValue(cutoff)))
        .go();
  }
}

class _MappedQuestion {
  const _MappedQuestion({
    required this.categoryId,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
  });

  final String categoryId;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption;
}

_MappedQuestion? _mapQuestion(
  Map<String, dynamic> raw, {
  required String fallbackCategoryId,
  required int maxQuestionChars,
  required int maxOptionChars,
}) {
  final question = _decodeHtml(raw['question']);
  final correctAnswer = _decodeHtml(raw['correct_answer']);
  final incorrectRaw = raw['incorrect_answers'];
  if (question.isEmpty ||
      question.length > maxQuestionChars ||
      correctAnswer.isEmpty) {
    return null;
  }
  if (incorrectRaw is! List) {
    return null;
  }
  final incorrect = <String>[];
  for (final answer in incorrectRaw) {
    final decoded = _decodeHtml(answer);
    if (decoded.isEmpty) {
      continue;
    }
    incorrect.add(decoded);
  }
  final type = (raw['type'] as String?)?.trim().toLowerCase();
  final isBoolean = type == 'boolean';
  if (isBoolean) {
    if (incorrect.isEmpty) {
      return null;
    }
    final options = <String>[correctAnswer, incorrect.first];
    final unique = options.toSet().toList();
    if (unique.length != 2 || unique.any((e) => e.length > maxOptionChars)) {
      return null;
    }
    unique.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final correct = unique.indexWhere((e) => e == correctAnswer);
    if (correct < 0) {
      return null;
    }
    return _MappedQuestion(
      categoryId: fallbackCategoryId,
      question: question,
      optionA: unique[0],
      optionB: unique[1],
      optionC: '',
      optionD: '',
      correctOption: correct == 0 ? 'A' : 'B',
    );
  }

  final options = <String>[correctAnswer, ...incorrect];
  final unique = options.toSet().toList();
  if (unique.length != 4 || unique.any((e) => e.length > maxOptionChars)) {
    return null;
  }
  unique.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final correctIdx = unique.indexWhere((e) => e == correctAnswer);
  if (correctIdx < 0) {
    return null;
  }
  final letters = ['A', 'B', 'C', 'D'];
  return _MappedQuestion(
    categoryId: fallbackCategoryId,
    question: question,
    optionA: unique[0],
    optionB: unique[1],
    optionC: unique[2],
    optionD: unique[3],
    correctOption: letters[correctIdx],
  );
}

String _decodeHtml(Object? raw) {
  if (raw is! String) {
    return '';
  }
  var s = raw;
  s = s.replaceAll('&quot;', '"');
  s = s.replaceAll('&#039;', "'");
  s = s.replaceAll('&apos;', "'");
  s = s.replaceAll('&amp;', '&');
  s = s.replaceAll('&lt;', '<');
  s = s.replaceAll('&gt;', '>');
  s = s.replaceAll('&eacute;', 'e');
  final numericEntityPattern = RegExp(r'&#(x?[0-9a-fA-F]+);');
  s = s.replaceAllMapped(numericEntityPattern, (match) {
    final token = match.group(1);
    if (token == null || token.isEmpty) {
      return '';
    }
    final code = token.startsWith('x') || token.startsWith('X')
        ? int.tryParse(token.substring(1), radix: 16)
        : int.tryParse(token);
    if (code == null) {
      return '';
    }
    return String.fromCharCode(code);
  });
  return s.trim();
}
