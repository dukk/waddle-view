import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/provider_runtime_config.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:drift/drift.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import 'quoterism_category.dart';
import 'quoterism_extra_config.dart';
import 'quoterism_http.dart';
import 'quoterism_quote_collect.dart';

const String kQuoterismLastPageKey = 'quoterism.last_page';

class QuoterismDataProvider implements IDataProvider {
  QuoterismDataProvider({
    http.Client? httpClient,
    DateTime Function()? nowUtc,
    Duration? requestTimeout,
  })  : _http = httpClient ?? http.Client(),
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
        _requestTimeout = requestTimeout ?? kQuoterismHttpTimeout;

  final http.Client _http;
  final DateTime Function() _nowUtc;
  final Duration _requestTimeout;

  @override
  String get id => kQuoteQuoterismIntegrationType;

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
    final nowUtc = _nowUtc();
    final nowMs = nowUtc.millisecondsSinceEpoch;
    final kv = IntegrationKvRepository(ctx.db);

    if (setting.pollSeconds > 0) {
      final lastValue =
          await kv.getIntegrationValue(integrationId, kIntegrationLastCollectKey);
      final last = int.tryParse(lastValue ?? '') ?? 0;
      if (nowMs - last < setting.pollSeconds * 1000) {
        ctx.diagnostics.provider(
          'quoterism: skip poll ($integrationId ${setting.pollSeconds}s gate)',
        );
        return;
      }
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(integrationId);
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('quoterism: resolveConfig', e, st);
      return;
    }

    final apiKey = config.accessToken;
    if (apiKey == null || apiKey.isEmpty) {
      ctx.diagnostics.provider('quoterism: skip (no API key) id=$integrationId');
      return;
    }

    final extra = QuoterismExtraConfig.parse(config.configJson);
    final base = normalizeQuoterismBaseUrl(config.baseUrl);
    final headers = quoterismRequestHeaders(apiKey);

    try {
      await pruneQuoterismQuotesByRetention(
        ctx,
        retentionDays: extra.retentionDays,
        nowMs: nowMs,
      );
      await pruneQuoterismQuotesByMaxCount(
        ctx,
        maxQuotes: extra.maxStoredQuotes,
      );

      var page = int.tryParse(
            await kv.getIntegrationValue(integrationId, kQuoterismLastPageKey) ??
                '',
          ) ??
          0;
      var stored = 0;

      for (var p = 0; p < extra.pagesPerCollect; p++) {
        final uri = buildQuoterismGetUri(
          baseUrl: base,
          path: '/api/quotes',
          query: {
            'page': '$page',
            'limit': '${extra.pageLimit}',
          },
        );
        ctx.diagnostics.provider(
          'quoterism: GET ${safeQuoterismUriForLog(uri)}',
        );

        final res = await _http
            .get(uri, headers: headers)
            .timeout(_requestTimeout);
        if (res.statusCode != 200) {
          ctx.diagnostics.provider(
            'quoterism: list status=${res.statusCode} page=$page',
          );
          break;
        }

        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) {
          break;
        }
        final data = decoded['data'];
        if (data is! List) {
          break;
        }

        var hasNext = false;
        final pagination = decoded['pagination'];
        if (pagination is Map) {
          hasNext = pagination['hasNextPage'] == true;
        }

        for (final item in data) {
          if (item is! Map) {
            continue;
          }
          final quoteId = item['id']?.toString().trim();
          final text = item['text']?.toString().trim();
          if (quoteId == null ||
              quoteId.isEmpty ||
              text == null ||
              text.isEmpty) {
            continue;
          }

          final detail = await _fetchQuoteDetail(
            ctx,
            base: base,
            headers: headers,
            quoteId: quoteId,
          );
          final merged = <String, dynamic>{
            ...item,
            if (detail != null) ...detail,
            'text': detail?['text'] ?? item['text'],
            'author': detail?['author'] ?? item['author'],
            'categories': detail?['categories'] ?? item['categories'],
            'category': detail?['category'] ?? item['category'],
            'tags': detail?['tags'] ?? item['tags'],
          };

          final author = merged['author'];
          String? authorId;
          String? authorName;
          String? authorSlug;
          String? imageUrl;
          if (author is Map) {
            authorId = author['id']?.toString();
            authorName = author['name']?.toString();
            authorSlug = author['slug']?.toString();
            imageUrl = author['imageUrl']?.toString();
          }

          final categories = <QuoterismCategoryRef>[
            ...parseQuoterismCategories(merged['categories']),
            ...parseQuoterismCategories(merged['category']),
            ...parseQuoterismCategories(merged['tags']),
          ];
          if (categories.isEmpty) {
            categories.add(
              const QuoterismCategoryRef(
                id: 'quoterism_general',
                label: 'General',
              ),
            );
          }

          DateTime? quoterismCreatedAt;
          final createdRaw = merged['createdAt']?.toString();
          if (createdRaw != null && createdRaw.isNotEmpty) {
            quoterismCreatedAt = DateTime.tryParse(createdRaw);
          }

          String? authorImageBlobKey;
          if (extra.fetchAuthorImages &&
              imageUrl != null &&
              imageUrl.trim().isNotEmpty) {
            authorImageBlobKey = await _downloadAuthorImage(
              ctx,
              imageUrl: imageUrl.trim(),
              authorId: authorId ?? authorSlug ?? quoteId,
              nowMs: nowMs,
            );
          } else {
            final existing = await (ctx.db.select(ctx.db.quoterismQuotes)
                  ..where((t) => t.id.equals(quoteId)))
                .getSingleOrNull();
            authorImageBlobKey = existing?.authorImageBlobKey;
          }

          final ok = await storeQuoterismQuote(
            ctx: ctx,
            quoteId: quoteId,
            text: text,
            authorId: authorId,
            authorName: authorName,
            authorSlug: authorSlug,
            authorImageBlobKey: authorImageBlobKey,
            quoterismCreatedAt: quoterismCreatedAt,
            integrationId: integrationId,
            categories: categories,
            nowMs: nowMs,
          );
          if (ok) {
            stored++;
          }
        }

        if (!hasNext) {
          page = 0;
        } else {
          page++;
        }
        await kv.upsertIntegration(
          integrationId: integrationId,
          key: kQuoterismLastPageKey,
          value: '$page',
        );
      }

      await kv.upsertIntegration(
        integrationId: integrationId,
        key: kIntegrationLastCollectKey,
        value: '$nowMs',
      );
      ctx.diagnostics.provider(
        'quoterism: stored=$stored integration=$integrationId page=$page',
      );
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('quoterism: collect', e, st);
    }
  }

  Future<Map<String, dynamic>?> _fetchQuoteDetail(
    DataWriteContext ctx, {
    required String base,
    required Map<String, String> headers,
    required String quoteId,
  }) async {
    final uri = buildQuoterismGetUri(
      baseUrl: base,
      path: '/api/quotes/$quoteId',
    );
    try {
      final res = await _http.get(uri, headers: headers).timeout(_requestTimeout);
      if (res.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('quoterism: detail $quoteId', e, st);
    }
    return null;
  }

  Future<String?> _downloadAuthorImage(
    DataWriteContext ctx, {
    required String imageUrl,
    required String authorId,
    required int nowMs,
  }) async {
    final logicalKey = 'quoterism/authors/$authorId/avatar';
    try {
      final existing = await (ctx.db.select(ctx.db.blobMetadata)
            ..where((t) => t.blobKey.equals(logicalKey)))
          .getSingleOrNull();
      if (existing != null) {
        return logicalKey;
      }

      final uri = Uri.parse(imageUrl);
      final res = await _http.get(uri).timeout(_requestTimeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        return null;
      }
      final mime = res.headers['content-type'] ?? 'image/jpeg';
      final ref = await ctx.blobs.putBytes(
        res.bodyBytes,
        logicalKey: logicalKey,
      );
      await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
            BlobMetadataCompanion.insert(
              blobKey: logicalKey,
              sha256: ref.storageKey.split('/').last,
              relativePath: ref.storageKey,
              bytes: res.bodyBytes.length,
              mimeType: Value(mime.split(';').first.trim()),
              capturedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
            ),
          );
      return logicalKey;
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('quoterism: author image', e, st);
      return null;
    }
  }
}
