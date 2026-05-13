import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_shared/config/provider_runtime_config.dart';
import '../../../debug/app_debug_log.dart';
import '../../../util/html_entity_decode.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../data_provider.dart';
import '../../data_write_context.dart';
import 'trivia_category_eligibility.dart';
import 'trivia_id.dart';
import 'trivia_provider_extra_config.dart'
    show
        TriviaProviderExtraConfig,
        kDefaultTriviaRateWindowMs;
import 'trivia_slot_allocation.dart';

const String kTriviaProviderId = 'trivia';

const String kDefaultOpenAiBaseUrl = 'https://api.openai.com/v1';

const int _kMaxTriviaQuestionChars = 90;
const int _kMaxTriviaOptionChars = 45;

const int _kRecentStemsForPromptLimit = 40;
const int _kRecentStemMaxChars = 120;

/// Fetches trivia via OpenAI Chat Completions and stores them in SQLite.
class TriviaDataProvider implements IDataProvider {
  TriviaDataProvider({
    http.Client? httpClient,
    DateTime Function()? now,
  })  : _http = httpClient ?? http.Client(),
        _now = now ?? DateTime.now;

  final http.Client _http;
  final DateTime Function() _now;

  @override
  String get id => kTriviaProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting =
        await (ctx.db.select(ctx.db.providerSettings)
              ..where((t) => t.id.equals(kTriviaProviderId)))
            .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      AppDebugLog.provider('trivia: skip (disabled)');
      return;
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(kTriviaProviderId);
    } on Object catch (e, st) {
      AppDebugLog.providerFail('trivia: resolveConfig', e, st);
      return;
    }

    final token = config.accessToken;
    if (token == null || token.isEmpty) {
      AppDebugLog.provider('trivia: skip (no API token)');
      return;
    }

    final extra = TriviaProviderExtraConfig.parse(config.configJson);
    if (extra.maxQuestionPerDay < 1) {
      AppDebugLog.provider('trivia: skip (maxQuestionPerDay < 1)');
      return;
    }

    final now = _now();
    final nowMs = now.millisecondsSinceEpoch;

    final purged = await _purgeTriviaPastRetention(
      ctx.db,
      nowMs,
      extra.questionRetentionDays,
    );
    if (purged > 0) {
      AppDebugLog.provider(
        'trivia: purged $purged question(s) older than retention',
      );
    }

    final startLocal = DateTime(now.year, now.month, now.day);
    final endLocal = startLocal.add(const Duration(days: 1));

    final todayCount = await _countTriviaInRange(ctx.db, startLocal, endLocal);
    final remainingDaily = extra.maxQuestionPerDay - todayCount;
    if (remainingDaily <= 0) {
      AppDebugLog.provider(
        'trivia: skip (daily cap $todayCount/${extra.maxQuestionPerDay})',
      );
      return;
    }

    final windowMs = extra.twoHourWindowMs > 0
        ? extra.twoHourWindowMs
        : kDefaultTriviaRateWindowMs;
    final sinceMs = nowMs - windowMs;
    final requestedInWindow =
        await _sumTriviaRequestedSince(ctx.db, sinceMs);
    final capWindow =
        extra.maxQuestionPerHour < 0 ? 0 : extra.maxQuestionPerHour;
    final remainingWindow = capWindow - requestedInWindow;
    if (remainingWindow <= 0) {
      AppDebugLog.provider(
        'trivia: rate window full '
        '($requestedInWindow/$capWindow in ${windowMs}ms)',
      );
      return;
    }

    final budget = remainingDaily < remainingWindow ? remainingDaily : remainingWindow;

    final allCategories =
        await ctx.db.select(ctx.db.triviaCategories).get();
    final eligible = allCategories
        .where((c) => isTriviaCategoryEligibleOn(c, now))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    if (eligible.isEmpty) {
      AppDebugLog.provider('trivia: no eligible categories');
      return;
    }

    final roundRobinStart =
        (nowMs ~/ Duration.millisecondsPerHour) % eligible.length;

    final storedByCategory = await _triviaCountsByCategory(ctx.db);
    final slots = buildTriviaRequestSlots(
      eligibleSorted: eligible,
      storedByCategoryId: storedByCategory,
      budget: budget,
      roundRobinStartIndex: roundRobinStart,
    );

    if (slots.isEmpty) {
      AppDebugLog.provider(
        'trivia: no slots (per-category max inventory)',
      );
      return;
    }

    await _pruneOldGenerationBatches(ctx.db, nowMs);

    final categoryById = {for (final c in eligible) c.id: c};

    final recentStems = await _recentTriviaQuestionStems(ctx.db);
    final userContent = _buildUserPrompt(
      slots,
      categoryById,
      recentStems,
      nowMs,
    );

    final baseUrl =
        (config.baseUrl != null && config.baseUrl!.trim().isNotEmpty)
        ? config.baseUrl!.trim()
        : kDefaultOpenAiBaseUrl;

    try {
      final uri = Uri.parse('$baseUrl/chat/completions');
      AppDebugLog.provider(
        'trivia: POST ${AppDebugLog.safeHttpUri(uri)} model=${extra.model} '
        'slots=${slots.length}',
      );
      final payload = <String, Object?>{
        'model': extra.model,
        'messages': [
          {'role': 'system', 'content': extra.globalPrompt},
          {'role': 'user', 'content': userContent},
        ],
      };
      if (extra.temperature != null) {
        payload['temperature'] = extra.temperature;
      }
      if (extra.maxOutputTokens != null) {
        payload['max_tokens'] = extra.maxOutputTokens;
      }

      final res = await _http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      if (res.statusCode != 200) {
        AppDebugLog.provider(
          'trivia: API status=${res.statusCode} bodyLen=${res.body.length}',
        );
        return;
      }

      await ctx.db.into(ctx.db.triviaGenerationBatches).insert(
            TriviaGenerationBatchesCompanion.insert(
              requestedAtMs: now,
              questionsRequested: slots.length,
            ),
          );

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        return;
      }
      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        return;
      }
      final message = first['message'];
      if (message is! Map<String, dynamic>) {
        return;
      }
      final content = message['content'];
      if (content is! String) {
        return;
      }

      final parsedList = _parseTriviaJsonArray(content);
      final createdAt = _now();
      var inserted = 0;

      final normalizedByCategory = await _normalizedQuestionsByCategory(
        ctx.db,
        categoryById.keys,
      );

      for (final item in parsedList) {
        final cid = item['categoryId'] as String?;
        final q = item['question'] as String?;
        final a = _stringField(item, 'A');
        final b = _stringField(item, 'B');
        final c = _stringField(item, 'C');
        final d = _stringField(item, 'D');
        final correctRaw = item['correct'];
        if (cid == null ||
            q == null ||
            a == null ||
            b == null ||
            correctRaw == null) {
          continue;
        }
        final isTrueFalse = c == null || d == null;
        final correctNorm = _normalizeCorrectOption(correctRaw, isTrueFalse);
        if (correctNorm == null) {
          continue;
        }
        final qt = decodeHtmlEntitiesFromField(q);
        final at = decodeHtmlEntitiesFromField(a);
        final bt = decodeHtmlEntitiesFromField(b);
        final ct = c != null ? decodeHtmlEntitiesFromField(c) : '';
        final dt = d != null ? decodeHtmlEntitiesFromField(d) : '';
        if (qt.isEmpty ||
            at.isEmpty ||
            bt.isEmpty ||
            (isTrueFalse ? false : (ct.isEmpty || dt.isEmpty))) {
          continue;
        }
        if (qt.length > _kMaxTriviaQuestionChars ||
            at.length > _kMaxTriviaOptionChars ||
            bt.length > _kMaxTriviaOptionChars ||
            (ct.length > _kMaxTriviaOptionChars) ||
            (dt.length > _kMaxTriviaOptionChars)) {
          continue;
        }
        if (!categoryById.containsKey(cid)) {
          continue;
        }
        final normQ = qt.toLowerCase();
        final existing = normalizedByCategory.putIfAbsent(cid, () => <String>{});
        if (existing.contains(normQ)) {
          continue;
        }
        final tid = triviaStableId(
          cid,
          qt,
          at,
          bt,
          ct,
          dt,
          correctNorm,
        );
        await ctx.db.into(ctx.db.triviaQuestions).insert(
              TriviaQuestionsCompanion.insert(
                id: tid,
                categoryId: cid,
                question: qt,
                optionA: at,
                optionB: bt,
                optionC: ct,
                optionD: dt,
                correctOption: correctNorm,
                createdAtMs: createdAt,
              ),
              onConflict: DoUpdate(
                (old) => TriviaQuestionsCompanion(
                  categoryId: Value(cid),
                  question: Value(qt),
                  optionA: Value(at),
                  optionB: Value(bt),
                  optionC: Value(ct),
                  optionD: Value(dt),
                  correctOption: Value(correctNorm),
                  createdAtMs: Value(createdAt),
                ),
              ),
            );
        existing.add(normQ);
        inserted++;
      }
      AppDebugLog.provider(
        'trivia: upserted $inserted question(s) from '
        '${parsedList.length} parsed object(s)',
      );
    } on Object catch (e, st) {
      AppDebugLog.providerFail('trivia: collect', e, st);
    }
  }

  static String? _stringField(Map<String, dynamic> item, String key) {
    final v = item[key];
    if (v is String) {
      return v;
    }
    return null;
  }

  static String? _normalizeCorrectOption(Object raw, bool isTrueFalse) {
    if (raw is! String) {
      return null;
    }
    final u = raw.trim().toUpperCase();
    if (isTrueFalse) {
      if (u == 'A' || u == 'B') {
        return u;
      }
      return null;
    }
    if (u == 'A' || u == 'B' || u == 'C' || u == 'D') {
      return u;
    }
    return null;
  }

  Future<List<String>> _recentTriviaQuestionStems(AppDatabase db) async {
    final rows = await (db.select(db.triviaQuestions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAtMs)])
          ..limit(_kRecentStemsForPromptLimit))
        .get();
    final seen = <String>{};
    final out = <String>[];
    for (final r in rows) {
      var t = r.question.trim();
      if (t.isEmpty || seen.contains(t)) {
        continue;
      }
      seen.add(t);
      if (t.length > _kRecentStemMaxChars) {
        t = '${t.substring(0, _kRecentStemMaxChars - 3)}...';
      }
      out.add(t);
    }
    return out;
  }

  Future<Map<String, Set<String>>> _normalizedQuestionsByCategory(
    AppDatabase db,
    Iterable<String> categoryIds,
  ) async {
    final ids = categoryIds.toList();
    if (ids.isEmpty) {
      return {};
    }
    final rows = await (db.select(db.triviaQuestions)
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

  Future<int> _countTriviaInRange(
    AppDatabase db,
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    final rows = await (db.select(db.triviaQuestions)
          ..where(
            (t) =>
                t.createdAtMs.isBiggerOrEqualValue(startInclusive) &
                t.createdAtMs.isSmallerThanValue(endExclusive),
          ))
        .get();
    return rows.length;
  }

  Future<Map<String, int>> _triviaCountsByCategory(AppDatabase db) async {
    final rows = await db.customSelect(
      'SELECT category_id AS c, COUNT(*) AS n FROM trivia_questions GROUP BY category_id',
      readsFrom: {db.triviaQuestions},
    ).get();
    return {for (final r in rows) r.read<String>('c'): r.read<int>('n')};
  }

  Future<int> _sumTriviaRequestedSince(
    AppDatabase db,
    int sinceMsInclusive,
  ) async {
    final since = DateTime.fromMillisecondsSinceEpoch(sinceMsInclusive);
    final rows = await (db.select(db.triviaGenerationBatches)
          ..where((t) => t.requestedAtMs.isBiggerOrEqualValue(since)))
        .get();
    var sum = 0;
    for (final r in rows) {
      sum += r.questionsRequested;
    }
    return sum;
  }

  Future<void> _pruneOldGenerationBatches(AppDatabase db, int nowMs) async {
    final cutoffMs = nowMs - const Duration(days: 7).inMilliseconds;
    final cutoff = DateTime.fromMillisecondsSinceEpoch(cutoffMs);
    await (db.delete(db.triviaGenerationBatches)
          ..where((t) => t.requestedAtMs.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<int> _purgeTriviaPastRetention(
    AppDatabase db,
    int nowMs,
    int retentionDays,
  ) async {
    if (retentionDays <= 0) {
      return 0;
    }
    final cutoffMs = nowMs - Duration(days: retentionDays).inMilliseconds;
    final cutoff = DateTime.fromMillisecondsSinceEpoch(cutoffMs);
    return (db.delete(db.triviaQuestions)
          ..where((t) => t.createdAtMs.isSmallerThanValue(cutoff)))
        .go();
  }

  static String _buildUserPrompt(
    List<TriviaCategory> slots,
    Map<String, TriviaCategory> categoryById,
    List<String> recentQuestionsToAvoid,
    int requestNonceMs,
  ) {
    final buf = StringBuffer()
      ..writeln(
        'Return ONLY a JSON array (no markdown fences, no commentary) with '
        'exactly ${slots.length} objects in this order (slot index matches '
        'array index).',
      )
      ..writeln(
        'Each object must be: '
        '{"categoryId": "<id>", "question": "<text>", '
        '"questionType":"multiple_choice"|"true_false", '
        '"A": "<choice>", "B": "<choice>", '
        '"C": "<choice|null>", "D": "<choice|null>", '
        '"correct": "A"|"B"|"C"|"D"}',
      )
      ..writeln(
        'Keep question at most $_kMaxTriviaQuestionChars characters and each '
        'choice at most $_kMaxTriviaOptionChars characters.',
      )
      ..writeln('Request nonce (for variety): $requestNonceMs');
    if (recentQuestionsToAvoid.isNotEmpty) {
      buf.writeln('Recent questions to avoid repeating or paraphrasing:');
      for (final q in recentQuestionsToAvoid) {
        buf.writeln('- $q');
      }
    }
    buf.writeln('Slots:');
    for (var i = 0; i < slots.length; i++) {
      final c = slots[i];
      buf.write('$i: categoryId=${c.id} (${c.label})');
      final p = c.categoryPrompt;
      if (p != null && p.isNotEmpty) {
        buf.write(' — $p');
      }
      buf.writeln();
    }
    buf.writeln('Allowed categoryId values: ${categoryById.keys.join(', ')}.');
    return buf.toString();
  }

  static List<Map<String, dynamic>> _parseTriviaJsonArray(String raw) {
    final trimmed = _stripMarkdownFence(raw);
    final decoded = jsonDecode(trimmed);
    if (decoded is! List) {
      return [];
    }
    final out = <Map<String, dynamic>>[];
    for (final e in decoded) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  static String _stripMarkdownFence(String raw) {
    var s = raw.trim();
    if (!s.startsWith('```')) {
      return s;
    }
    final firstNl = s.indexOf('\n');
    if (firstNl != -1) {
      s = s.substring(firstNl + 1);
    }
    final fence = s.lastIndexOf('```');
    if (fence != -1) {
      s = s.substring(0, fence);
    }
    return s.trim();
  }
}
