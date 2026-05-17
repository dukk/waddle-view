import 'package:waddle_shared/net/http_debug_uri.dart';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_shared/config/provider_runtime_config.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/data_ingest/joke_ingest.dart';
import 'package:waddle_shared/data_model/joke_candidate.dart';
import 'package:waddle_shared/text/html_entity_decode.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'joke_provider_extra_config.dart'
    show
        JokeProviderExtraConfig,
        kDefaultTwoHourWindowMs;
import 'joke_seasonal_eligibility.dart';
import 'joke_slot_allocation.dart';
import '../openai/openai_api_base_url.dart';

const String kJokeProviderId = 'joke_openai';

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
        await (ctx.db.select(ctx.db.integrations)
              ..where((t) => t.id.equals(kJokeProviderId)))
            .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      ctx.diagnostics.provider('jokes: skip (disabled)');
      return;
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(kJokeProviderId);
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('jokes: resolveConfig', e, st);
      return;
    }

    final token = config.accessToken;
    if (token == null || token.isEmpty) {
      ctx.diagnostics.provider('jokes: skip (no API token)');
      return;
    }

    final extra = JokeProviderExtraConfig.parse(config.configJson);
    if (extra.jokesPerDay < 1) {
      ctx.diagnostics.provider('jokes: skip (jokesPerDay < 1)');
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
      ctx.diagnostics.provider('jokes: purged $purged joke(s) older than retention');
    }

    final startLocal = DateTime(now.year, now.month, now.day);
    final endLocal = startLocal.add(const Duration(days: 1));

    final todayCount = await _countJokesInRange(ctx.db, startLocal, endLocal);
    final remainingDaily = extra.jokesPerDay - todayCount;
    if (remainingDaily <= 0) {
      ctx.diagnostics.provider('jokes: skip (daily cap $todayCount/${extra.jokesPerDay})');
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
      ctx.diagnostics.provider(
        'jokes: 2h window full ($requestedInWindow/$cap2h in ${windowMs}ms)',
      );
      return;
    }

    final budget = remainingDaily < remaining2h ? remainingDaily : remaining2h;

    final allCategories =
        await ctx.db.select(ctx.db.interestsJokes).get();
    final eligible = allCategories
        .where((c) => isJokeCategoryEligibleOn(c, now))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    if (eligible.isEmpty) {
      ctx.diagnostics.provider('jokes: no eligible categories');
      return;
    }

    final storedByCategory = await _jokeCountsByCategory(ctx.db);
    final slots = buildJokeRequestSlots(
      eligibleSorted: eligible,
      storedByCategoryId: storedByCategory,
      budget: budget,
    );

    if (slots.isEmpty) {
      ctx.diagnostics.provider('jokes: no slots (per-category min/max vs inventory)');
      return;
    }

    await _pruneOldGenerationBatches(ctx.db, nowMs);

    final categoryById = {for (final c in eligible) c.id: c};

    final baseUrl =
        (config.baseUrl != null && config.baseUrl!.trim().isNotEmpty)
        ? config.baseUrl!.trim()
        : kDefaultOpenAiBaseUrl;

    final userContent = _buildUserPrompt(slots, categoryById);

    try {
      final uri = Uri.parse('$baseUrl/chat/completions');
      ctx.diagnostics.provider(
        'jokes: POST ${safeHttpUriForLog(uri)} model=${extra.model} '
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
        ctx.diagnostics.provider(
          'jokes: API status=${res.statusCode} bodyLen=${res.body.length}',
        );
        return;
      }

      await ctx.db.into(ctx.db.jokeGenerationBatches).insert(
            JokeGenerationBatchesCompanion.insert(
              requestedAtMs: now,
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
      final createdAt = _now();
      final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);
      final candidates = <JokeCandidate>[];
      for (final item in parsedList) {
        final cid = item['categoryId'] as String?;
        final setupRaw = item['setup'] as String?;
        final punchlineRaw = item['punchline'] as String?;
        final setup = decodeHtmlEntitiesFromField(setupRaw);
        final punchline = decodeHtmlEntitiesFromField(punchlineRaw);
        if (cid == null ||
            setupRaw == null ||
            punchlineRaw == null ||
            setup.isEmpty ||
            punchline.isEmpty) {
          continue;
        }
        if (!categoryById.containsKey(cid)) {
          continue;
        }
        candidates.add(
          JokeCandidate(categoryId: cid, setup: setup, punchline: punchline),
        );
      }
      final inserted = await ingestJokeCandidates(
        db: ctx.db,
        rejectCtx: rejectCtx,
        allowedCategoryIds: categoryById.keys.toSet(),
        createdAt: createdAt,
        candidates: candidates,
      );
      ctx.diagnostics.provider(
        'jokes: upserted $inserted joke(s) from ${parsedList.length} parsed object(s)',
      );
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('jokes: collect', e, st);
    }
  }

  Future<int> _countJokesInRange(
    AppDatabase db,
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    final rows = await (db.select(db.jokes)
          ..where(
            (t) =>
                t.createdAtMs.isBiggerOrEqualValue(startInclusive) &
                t.createdAtMs.isSmallerThanValue(endExclusive),
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
    final since = DateTime.fromMillisecondsSinceEpoch(sinceMsInclusive);
    final rows = await (db.select(db.jokeGenerationBatches)
          ..where((t) => t.requestedAtMs.isBiggerOrEqualValue(since)))
        .get();
    var sum = 0;
    for (final r in rows) {
      sum += r.jokesRequested;
    }
    return sum;
  }

  Future<void> _pruneOldGenerationBatches(AppDatabase db, int nowMs) async {
    final cutoffMs = nowMs - const Duration(days: 14).inMilliseconds;
    final cutoff = DateTime.fromMillisecondsSinceEpoch(cutoffMs);
    await (db.delete(db.jokeGenerationBatches)
          ..where((t) => t.requestedAtMs.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Removes jokes with creation time strictly before `now - retentionDays`.
  /// Returns the number of rows deleted. No-op if [retentionDays] `<= 0`.
  Future<int> _purgeJokesPastRetention(
    AppDatabase db,
    int nowMs,
    int retentionDays,
  ) async {
    if (retentionDays <= 0) {
      return 0;
    }
    final cutoffMs = nowMs - Duration(days: retentionDays).inMilliseconds;
    final cutoff = DateTime.fromMillisecondsSinceEpoch(cutoffMs);
    return (db.delete(db.jokes)
          ..where((t) => t.createdAtMs.isSmallerThanValue(cutoff)))
        .go();
  }

  static String _buildUserPrompt(
    List<InterestsJoke> slots,
    Map<String, InterestsJoke> categoryById,
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
