import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/provider_runtime_config.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/data_ingest/joke_ingest.dart';
import 'package:waddle_shared/data_model/joke_candidate.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/net/http_debug_uri.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/text/html_entity_decode.dart';

import '../joke_openai/joke_seasonal_eligibility.dart';
import 'jokeapi_extra_config.dart';
import 'jokeapi_http.dart';

const String kJokeApiProviderId = 'joke_jokeapi';

class JokeApiDataProvider implements IDataProvider {
  JokeApiDataProvider({
    http.Client? httpClient,
    DateTime Function()? now,
    Random? random,
    Duration? requestTimeout,
  })  : _http = httpClient ?? http.Client(),
        _now = now ?? DateTime.now,
        _random = random ?? Random(),
        _requestTimeout = requestTimeout ?? kJokeApiHttpTimeout;

  final http.Client _http;
  final DateTime Function() _now;
  final Random _random;
  final Duration _requestTimeout;

  @override
  String get id => kJokeApiProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final rows = await enabledIntegrationsForType(ctx.db, id);
    for (final setting in rows) {
      await _collectIntegration(ctx, setting);
    }
  }

  Future<void> _collectIntegration(
    DataWriteContext ctx,
    Integration setting,
  ) async {
    final integrationId = setting.id;
    final now = _now();
    final nowMs = now.millisecondsSinceEpoch;
    final kv = IntegrationKvRepository(ctx.db);

    final rateLimitUntil = int.tryParse(
          await kv.getIntegrationValue(integrationId, kJokeApiRateLimitUntilKey) ??
              '',
        ) ??
        0;
    if (nowMs < rateLimitUntil) {
      ctx.diagnostics.provider(
        'joke_jokeapi: skip rate limit ($integrationId until=$rateLimitUntil)',
      );
      return;
    }

    if (setting.pollSeconds > 0) {
      final lastValue =
          await kv.getIntegrationValue(integrationId, kIntegrationLastCollectKey);
      final last = int.tryParse(lastValue ?? '') ?? 0;
      if (nowMs - last < setting.pollSeconds * 1000) {
        ctx.diagnostics.provider(
          'joke_jokeapi: skip poll ($integrationId ${setting.pollSeconds}s gate)',
        );
        return;
      }
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(integrationId);
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('joke_jokeapi: resolveConfig', e, st);
      return;
    }

    final extra = JokeApiExtraConfig.parse(config.configJson);
    if (extra.categoryMap.isEmpty) {
      ctx.diagnostics.provider('joke_jokeapi: skip (empty categoryMap)');
      return;
    }

    final purged = await _purgeJokesPastRetention(
      ctx,
      nowMs: nowMs,
      retentionDays: extra.jokeRetentionDays,
    );
    if (purged > 0) {
      ctx.diagnostics.provider('joke_jokeapi: purged $purged old joke(s)');
    }

    final categories = await ctx.db.select(ctx.db.interestsJokes).get();
    final eligible = categories
        .where((c) => isJokeCategoryEligibleOn(c, now))
        .where((c) => extra.categoryMap.containsKey(c.id))
        .toList();
    if (eligible.isEmpty) {
      ctx.diagnostics.provider('joke_jokeapi: no eligible mapped categories');
      return;
    }

    final picked = eligible[_random.nextInt(eligible.length)];
    final apiCategory = extra.categoryMap[picked.id]!;
    final baseUrl = config.baseUrl;
    final uri = buildJokeApiUri(
      baseUrl: baseUrl ?? kDefaultJokeApiBaseUrl,
      apiCategory: apiCategory,
      amount: extra.jokesPerPoll,
      blacklistFlags: extra.blacklistFlags,
      contains: extra.contains,
    );
    ctx.diagnostics.provider('joke_jokeapi: GET ${safeHttpUriForLog(uri)}');

    try {
      final res = await _http
          .get(
            uri,
            headers: const {'User-Agent': kJokeApiUserAgent},
          )
          .timeout(_requestTimeout);

      logJokeApiRateLimitHeaders(ctx.diagnostics, res);

      final backoffUntil = jokeApiRateLimitUntilMsFromResponse(res, nowMs);
      if (backoffUntil != null) {
        await kv.upsertIntegration(
          integrationId: integrationId,
          key: kJokeApiRateLimitUntilKey,
          value: '$backoffUntil',
          valueType: kIntegrationKvTypeIntMs,
        );
      }

      if (res.statusCode != 200) {
        ctx.diagnostics.provider(
          'joke_jokeapi: status=${res.statusCode} bodyLen=${res.body.length}',
        );
        return;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        ctx.diagnostics.provider('joke_jokeapi: JSON top-level not an object');
        return;
      }

      if (decoded['error'] == true) {
        final message = decoded['message'] as String? ?? 'unknown';
        ctx.diagnostics.provider('joke_jokeapi: API error message=$message');
        return;
      }

      final rawJokes = _extractJokeMaps(decoded);
      final candidates = <JokeCandidate>[];
      for (final raw in rawJokes) {
        final candidate = _mapTwopartJoke(raw, storeCategoryId: picked.id);
        if (candidate != null) {
          candidates.add(candidate);
        }
      }

      if (candidates.isEmpty) {
        ctx.diagnostics.provider('joke_jokeapi: no twopart jokes to ingest');
        return;
      }

      final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);
      final allowedIds = {for (final c in eligible) c.id};
      final inserted = await ingestJokeCandidates(
        db: ctx.db,
        rejectCtx: rejectCtx,
        allowedCategoryIds: allowedIds,
        createdAt: now,
        candidates: candidates,
      );

      await kv.upsertIntegration(
        integrationId: integrationId,
        key: kIntegrationLastCollectKey,
        value: '$nowMs',
        valueType: kIntegrationKvTypeIntMs,
      );

      ctx.diagnostics.provider(
        'joke_jokeapi: upserted $inserted joke(s) from ${rawJokes.length} item(s)',
      );
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('joke_jokeapi: collect', e, st);
    }
  }

  Future<int> _purgeJokesPastRetention(
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
    return (ctx.db.delete(ctx.db.jokes)
          ..where((t) => t.createdAtMs.isSmallerThanValue(cutoff)))
        .go();
  }
}

List<Map<String, dynamic>> _extractJokeMaps(Map<String, dynamic> decoded) {
  final jokes = decoded['jokes'];
  if (jokes is List) {
    return [
      for (final item in jokes)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  if (decoded.containsKey('setup') || decoded.containsKey('delivery')) {
    return [decoded];
  }
  return const [];
}

JokeCandidate? _mapTwopartJoke(
  Map<String, dynamic> raw, {
  required String storeCategoryId,
}) {
  final type = (raw['type'] as String?)?.trim().toLowerCase();
  if (type != 'twopart') {
    return null;
  }
  final setup = decodeHtmlEntitiesFromField(raw['setup']);
  final punchline = decodeHtmlEntitiesFromField(raw['delivery']);
  if (setup.isEmpty || punchline.isEmpty) {
    return null;
  }
  return JokeCandidate(
    categoryId: storeCategoryId,
    setup: setup,
    punchline: punchline,
  );
}
