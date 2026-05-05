import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../config/provider_runtime_config.dart';
import '../../debug/app_debug_log.dart';
import '../../persistence/database.dart';
import '../data_provider.dart';
import '../data_write_context.dart';
import 'trivia_category_eligibility.dart';
import 'trivia_id.dart';
import 'trivia_provider_extra_config.dart'
    show
        TriviaProviderExtraConfig,
        kDefaultTriviaTwoHourWindowMs;
import 'trivia_slot_allocation.dart';
import 'category_icon_service.dart';

const String kTriviaProviderId = 'trivia';

const String kDefaultOpenAiBaseUrl = 'https://api.openai.com/v1';

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
      return;
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(kTriviaProviderId);
    } on Object catch (e, st) {
      AppDebugLog.engineFail('TriviaDataProvider resolveConfig', e, st);
      return;
    }

    final token = config.accessToken;
    if (token == null || token.isEmpty) {
      AppDebugLog.engine(
        'TriviaDataProvider: skip collect (no API token for $kTriviaProviderId)',
      );
      return;
    }

    final extra = TriviaProviderExtraConfig.parse(config.extraJson);
    if (extra.questionsPerDay < 1) {
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
      AppDebugLog.engine(
        'TriviaDataProvider: purged $purged question(s) older than retention',
      );
    }

    final startLocal = DateTime(now.year, now.month, now.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    final startMs = startLocal.millisecondsSinceEpoch;
    final endMs = endLocal.millisecondsSinceEpoch;

    final todayCount = await _countTriviaInRange(ctx.db, startMs, endMs);
    final remainingDaily = extra.questionsPerDay - todayCount;
    if (remainingDaily <= 0) {
      return;
    }

    final windowMs = extra.twoHourWindowMs > 0
        ? extra.twoHourWindowMs
        : kDefaultTriviaTwoHourWindowMs;
    final sinceMs = nowMs - windowMs;
    final requestedInWindow =
        await _sumTriviaRequestedSince(ctx.db, sinceMs);
    final cap2h =
        extra.maxQuestionsPerTwoHours < 0 ? 0 : extra.maxQuestionsPerTwoHours;
    final remaining2h = cap2h - requestedInWindow;
    if (remaining2h <= 0) {
      AppDebugLog.engine(
        'TriviaDataProvider: 2h window full '
        '($requestedInWindow/$cap2h in ${windowMs}ms)',
      );
      return;
    }

    final budget = remainingDaily < remaining2h ? remainingDaily : remaining2h;

    final allCategories =
        await ctx.db.select(ctx.db.triviaCategories).get();
    final eligible = allCategories
        .where((c) => isTriviaCategoryEligibleOn(c, now))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    if (eligible.isEmpty) {
      AppDebugLog.engine('TriviaDataProvider: no eligible categories');
      return;
    }

    final storedByCategory = await _triviaCountsByCategory(ctx.db);
    final slots = buildTriviaRequestSlots(
      eligibleSorted: eligible,
      storedByCategoryId: storedByCategory,
      budget: budget,
    );

    if (slots.isEmpty) {
      AppDebugLog.engine(
        'TriviaDataProvider: no slots (per-category min/max vs inventory)',
      );
      return;
    }

    await _pruneOldGenerationBatches(ctx.db, nowMs);

    final categoryById = {for (final c in eligible) c.id: c};

    final baseUrl =
        (config.baseUrl != null && config.baseUrl!.trim().isNotEmpty)
        ? config.baseUrl!.trim()
        : kDefaultOpenAiBaseUrl;
    await ensureCategoryIcons(
      ctx: ctx,
      httpClient: _http,
      baseUrl: baseUrl,
      token: token,
      categoryType: 'trivia',
      categories: eligible.map((c) => (id: c.id, label: c.label)),
      limit: 4,
    );

    final userContent = _buildUserPrompt(slots, categoryById);

    try {
      final uri = Uri.parse('$baseUrl/chat/completions');
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
        AppDebugLog.engine(
          'TriviaDataProvider: API status ${res.statusCode} body len=${res.body.length}',
        );
        return;
      }

      await ctx.db.into(ctx.db.triviaGenerationBatches).insert(
            TriviaGenerationBatchesCompanion.insert(
              requestedAtMs: nowMs,
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
      final createdAt = _now().millisecondsSinceEpoch;

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
            c == null ||
            d == null ||
            correctRaw == null) {
          continue;
        }
        final correctNorm = _normalizeCorrectOption(correctRaw);
        if (correctNorm == null) {
          continue;
        }
        if (q.trim().isEmpty ||
            a.trim().isEmpty ||
            b.trim().isEmpty ||
            c.trim().isEmpty ||
            d.trim().isEmpty) {
          continue;
        }
        if (!categoryById.containsKey(cid)) {
          continue;
        }
        final tid = triviaStableId(
          cid,
          q.trim(),
          a.trim(),
          b.trim(),
          c.trim(),
          d.trim(),
          correctNorm,
        );
        await ctx.db.into(ctx.db.triviaQuestions).insertOnConflictUpdate(
              TriviaQuestionsCompanion.insert(
                id: tid,
                categoryId: cid,
                question: q.trim(),
                optionA: a.trim(),
                optionB: b.trim(),
                optionC: c.trim(),
                optionD: d.trim(),
                correctOption: correctNorm,
                createdAtMs: createdAt,
              ),
            );
      }
    } on Object catch (e, st) {
      AppDebugLog.engineFail('TriviaDataProvider collect', e, st);
    }
  }

  static String? _stringField(Map<String, dynamic> item, String key) {
    final v = item[key];
    if (v is String) {
      return v;
    }
    return null;
  }

  static String? _normalizeCorrectOption(Object raw) {
    if (raw is! String) {
      return null;
    }
    final u = raw.trim().toUpperCase();
    if (u == 'A' || u == 'B' || u == 'C' || u == 'D') {
      return u;
    }
    return null;
  }

  Future<int> _countTriviaInRange(
    AppDatabase db,
    int startMsInclusive,
    int endMsExclusive,
  ) async {
    final rows = await (db.select(db.triviaQuestions)
          ..where(
            (t) =>
                t.createdAtMs.isBiggerOrEqualValue(startMsInclusive) &
                t.createdAtMs.isSmallerThanValue(endMsExclusive),
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
    final rows = await (db.select(db.triviaGenerationBatches)
          ..where((t) => t.requestedAtMs.isBiggerOrEqualValue(sinceMsInclusive)))
        .get();
    var sum = 0;
    for (final r in rows) {
      sum += r.questionsRequested;
    }
    return sum;
  }

  Future<void> _pruneOldGenerationBatches(AppDatabase db, int nowMs) async {
    final cutoff = nowMs - const Duration(days: 14).inMilliseconds;
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
    final cutoff = nowMs - Duration(days: retentionDays).inMilliseconds;
    return (db.delete(db.triviaQuestions)
          ..where((t) => t.createdAtMs.isSmallerThanValue(cutoff)))
        .go();
  }

  static String _buildUserPrompt(
    List<TriviaCategory> slots,
    Map<String, TriviaCategory> categoryById,
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
        '"A": "<choice>", "B": "<choice>", "C": "<choice>", "D": "<choice>", '
        '"correct": "A"|"B"|"C"|"D"}',
      )
      ..writeln('Slots:');
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
