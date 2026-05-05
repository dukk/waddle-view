import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../config/provider_runtime_config.dart';
import '../../debug/app_debug_log.dart';
import '../../persistence/database.dart';
import '../data_provider.dart';
import '../data_write_context.dart';
import 'joke_id.dart';
import 'joke_provider_extra_config.dart'
    show
        JokeProviderExtraConfig,
        kDefaultTwoHourWindowMs;
import 'joke_seasonal_eligibility.dart';
import 'joke_slot_allocation.dart';
import 'category_icon_service.dart';

const String kJokeProviderId = 'jokes';

const String kDefaultOpenAiBaseUrl = 'https://api.openai.com/v1';

/// Fetches jokes via OpenAI Chat Completions and stores them in SQLite.
class JokeDataProvider implements IDataProvider {
  JokeDataProvider({
    http.Client? httpClient,
    DateTime Function()? now,
  })  : _http = httpClient ?? http.Client(),
        _now = now ?? DateTime.now;

  final http.Client _http;
  final DateTime Function() _now;

  @override
  String get id => kJokeProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting =
        await (ctx.db.select(ctx.db.providerSettings)
              ..where((t) => t.id.equals(kJokeProviderId)))
            .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      return;
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(kJokeProviderId);
    } on Object catch (e, st) {
      AppDebugLog.engineFail('JokeDataProvider resolveConfig', e, st);
      return;
    }

    final token = config.accessToken;
    if (token == null || token.isEmpty) {
      AppDebugLog.engine(
        'JokeDataProvider: skip collect (no API token for $kJokeProviderId)',
      );
      return;
    }

    final extra = JokeProviderExtraConfig.parse(config.extraJson);
    if (extra.jokesPerDay < 1) {
      return;
    }

    final now = _now();
    final nowMs = now.millisecondsSinceEpoch;

    final purged = await _purgeJokesPastRetention(
      ctx.db,
      nowMs,
      extra.jokeRetentionDays,
    );
    if (purged > 0) {
      AppDebugLog.engine(
        'JokeDataProvider: purged $purged joke(s) older than retention',
      );
    }

    final startLocal = DateTime(now.year, now.month, now.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    final startMs = startLocal.millisecondsSinceEpoch;
    final endMs = endLocal.millisecondsSinceEpoch;

    final todayCount = await _countJokesInRange(ctx.db, startMs, endMs);
    final remainingDaily = extra.jokesPerDay - todayCount;
    if (remainingDaily <= 0) {
      return;
    }

    final windowMs = extra.twoHourWindowMs > 0
        ? extra.twoHourWindowMs
        : kDefaultTwoHourWindowMs;
    final sinceMs = nowMs - windowMs;
    final requestedInWindow =
        await _sumJokesRequestedSince(ctx.db, sinceMs);
    final cap2h = extra.maxJokesPerTwoHours < 0 ? 0 : extra.maxJokesPerTwoHours;
    final remaining2h = cap2h - requestedInWindow;
    if (remaining2h <= 0) {
      AppDebugLog.engine(
        'JokeDataProvider: 2h window full '
        '($requestedInWindow/$cap2h in ${windowMs}ms)',
      );
      return;
    }

    final budget = remainingDaily < remaining2h ? remainingDaily : remaining2h;

    final allCategories =
        await ctx.db.select(ctx.db.jokeCategories).get();
    final eligible = allCategories
        .where((c) => isJokeCategoryEligibleOn(c, now))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    if (eligible.isEmpty) {
      AppDebugLog.engine('JokeDataProvider: no eligible categories');
      return;
    }

    final storedByCategory = await _jokeCountsByCategory(ctx.db);
    final slots = buildJokeRequestSlots(
      eligibleSorted: eligible,
      storedByCategoryId: storedByCategory,
      budget: budget,
    );

    if (slots.isEmpty) {
      AppDebugLog.engine(
        'JokeDataProvider: no slots (per-category min/max vs inventory)',
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
      categoryType: 'joke',
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
          'JokeDataProvider: API status ${res.statusCode} body len=${res.body.length}',
        );
        return;
      }

      await ctx.db.into(ctx.db.jokeGenerationBatches).insert(
            JokeGenerationBatchesCompanion.insert(
              requestedAtMs: nowMs,
              jokesRequested: slots.length,
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

      final parsedList = _parseJokeJsonArray(content);
      final createdAt = _now().millisecondsSinceEpoch;

      for (final item in parsedList) {
        final cid = item['categoryId'] as String?;
        final setup = item['setup'] as String?;
        final punchline = item['punchline'] as String?;
        if (cid == null ||
            setup == null ||
            punchline == null ||
            setup.trim().isEmpty ||
            punchline.trim().isEmpty) {
          continue;
        }
        if (!categoryById.containsKey(cid)) {
          continue;
        }
        final jokeId = jokeStableId(cid, setup.trim(), punchline.trim());
        await ctx.db.into(ctx.db.jokes).insertOnConflictUpdate(
              JokesCompanion.insert(
                id: jokeId,
                categoryId: cid,
                setup: setup.trim(),
                punchline: punchline.trim(),
                createdAtMs: createdAt,
              ),
            );
      }
    } on Object catch (e, st) {
      AppDebugLog.engineFail('JokeDataProvider collect', e, st);
    }
  }

  Future<int> _countJokesInRange(
    AppDatabase db,
    int startMsInclusive,
    int endMsExclusive,
  ) async {
    final rows = await (db.select(db.jokes)
          ..where(
            (t) =>
                t.createdAtMs.isBiggerOrEqualValue(startMsInclusive) &
                t.createdAtMs.isSmallerThanValue(endMsExclusive),
          ))
        .get();
    return rows.length;
  }

  Future<Map<String, int>> _jokeCountsByCategory(AppDatabase db) async {
    final rows = await db.customSelect(
      'SELECT category_id AS c, COUNT(*) AS n FROM jokes GROUP BY category_id',
      readsFrom: {db.jokes},
    ).get();
    return {for (final r in rows) r.read<String>('c'): r.read<int>('n')};
  }

  Future<int> _sumJokesRequestedSince(AppDatabase db, int sinceMsInclusive) async {
    final rows = await (db.select(db.jokeGenerationBatches)
          ..where((t) => t.requestedAtMs.isBiggerOrEqualValue(sinceMsInclusive)))
        .get();
    var sum = 0;
    for (final r in rows) {
      sum += r.jokesRequested;
    }
    return sum;
  }

  Future<void> _pruneOldGenerationBatches(AppDatabase db, int nowMs) async {
    final cutoff = nowMs - const Duration(days: 14).inMilliseconds;
    await (db.delete(db.jokeGenerationBatches)
          ..where((t) => t.requestedAtMs.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Removes jokes with [Joke.createdAtMs] strictly before `now - retentionDays`.
  /// Returns the number of rows deleted. No-op if [retentionDays] `<= 0`.
  Future<int> _purgeJokesPastRetention(
    AppDatabase db,
    int nowMs,
    int retentionDays,
  ) async {
    if (retentionDays <= 0) {
      return 0;
    }
    final cutoff = nowMs - Duration(days: retentionDays).inMilliseconds;
    return (db.delete(db.jokes)
          ..where((t) => t.createdAtMs.isSmallerThanValue(cutoff)))
        .go();
  }

  static String _buildUserPrompt(
    List<JokeCategory> slots,
    Map<String, JokeCategory> categoryById,
  ) {
    final buf = StringBuffer()
      ..writeln(
        'Return ONLY a JSON array (no markdown fences, no commentary) with '
        'exactly ${slots.length} objects in this order (slot index matches '
        'array index).',
      )
      ..writeln(
        'Each object must be: '
        '{"categoryId": "<id>", "setup": "<text>", "punchline": "<text>"}',
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
    // Mention allowed ids once for validation discipline.
    buf.writeln('Allowed categoryId values: ${categoryById.keys.join(', ')}.');
    return buf.toString();
  }

  static List<Map<String, dynamic>> _parseJokeJsonArray(String raw) {
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
