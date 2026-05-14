import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/curation/reject_filter_context.dart';

import '../../../blob/blob_store.dart';
import '../../../debug/app_debug_log.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../data_provider.dart';
import '../../data_write_context.dart';
import 'rss_feed_parsing.dart';
import 'rss_http_response_body_decode.dart';

String rssArticleId(String feedId, String stableItemKey) {
  final h = sha256.convert(utf8.encode('$feedId\x00$stableItemKey'));
  return h.toString();
}

class RssNewsDataProvider implements IDataProvider {
  RssNewsDataProvider({http.Client? httpClient, int Function()? nowMs})
    : _http = httpClient ?? http.Client(),
      _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final http.Client _http;
  final int Function() _nowMs;

  @override
  String get id => 'rss';

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final now = _nowMs();
    final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);
    final feedRows = await (ctx.db.select(
      ctx.db.rssFeedSources,
    )..where((t) => t.enabled.equals(true))).get();
    if (feedRows.isEmpty) {
      AppDebugLog.provider('rss: collect skip (no enabled feeds)');
      return;
    }
    AppDebugLog.provider('rss: collect enabledFeeds=${feedRows.length}');
    for (final feed in feedRows) {
      final last = feed.lastFetchedAt;
      final due = last == null ||
          (now - last.millisecondsSinceEpoch) >= feed.pollSeconds * 1000;
      if (!due) {
        AppDebugLog.provider(
          'rss: skip feed id=${feed.id} (poll ${feed.pollSeconds}s not due)',
        );
        continue;
      }
      try {
        final feedUri = Uri.parse(feed.url);
        AppDebugLog.provider(
          'rss: GET feed id=${feed.id} ${AppDebugLog.safeHttpUri(feedUri)}',
        );
        final res = await _http.get(feedUri);
        if (res.statusCode != 200) {
          AppDebugLog.provider(
            'rss: feed id=${feed.id} status=${res.statusCode} '
            '${AppDebugLog.safeHttpUri(feedUri)}',
          );
          continue;
        }
        // [parseRssOrAtomXml] normalizes item/channel text (entities, tags,
        // non-printing characters) for display.
        final parsed = parseRssOrAtomXml(decodeRssHttpResponseBody(res));
        final title = parsed.channelTitle;
        if (title != null && title.isNotEmpty) {
          await (ctx.db.update(
            ctx.db.rssFeedSources,
          )..where((t) => t.id.equals(feed.id))).write(
            RssFeedSourcesCompanion(title: Value(title)),
          );
        }
        AppDebugLog.provider(
          'rss: feed id=${feed.id} parsed entries=${parsed.entries.length}',
        );
        for (final e in parsed.entries) {
          await _upsertArticle(
            ctx,
            feedId: feed.id,
            entry: e,
            now: now,
            rejectCtx: rejectCtx,
          );
        }
        await _pruneFeedArticles(ctx, feed.id, feed.maxArticles);
        await (ctx.db.update(
          ctx.db.rssFeedSources,
        )..where((t) => t.id.equals(feed.id))).write(
          RssFeedSourcesCompanion(
            lastFetchedAt: Value(DateTime.fromMillisecondsSinceEpoch(now)),
          ),
        );
      } on Object catch (e, st) {
        AppDebugLog.providerFail('rss: feed id=${feed.id}', e, st);
      }
    }
  }

  Future<void> _upsertArticle(
    DataWriteContext ctx, {
    required String feedId,
    required ParsedFeedEntry entry,
    required int now,
    required RejectFilterContext rejectCtx,
  }) async {
    final articleId = rssArticleId(feedId, entry.stableKey);
    final existing = await (ctx.db.select(
      ctx.db.rssArticles,
    )..where((t) => t.id.equals(articleId))).getSingleOrNull();
    var imageKey = existing?.imageBlobKey;
    if (entry.imageUrl != null &&
        entry.imageUrl!.isNotEmpty &&
        imageKey == null) {
      imageKey = await _downloadAndStoreImage(
        ctx,
        feedId: feedId,
        articleId: articleId,
        imageUrl: entry.imageUrl!,
      );
    }

    // Pre-suppress new rows that match a `block` reject term so the curator
    // never schedules them. Existing suppressed rows stay suppressed; clean
    // rows that were never blocked retain their current `suppressed` value
    // through the upsert (we only force `suppressed = true` on a match).
    final isBlocked = rejectCtx.isBlockedAny([entry.title, entry.summary]);
    final suppressedForInsert = (existing?.suppressed ?? false) || isBlocked;

    await ctx.db.into(ctx.db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: articleId,
            feedId: feedId,
            guid: entry.stableKey,
            title: entry.title,
            link: entry.link,
            summary: Value(entry.summary),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(
              entry.publishedAtMs,
              isUtc: true,
            ),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(now),
            imageBlobKey: Value(imageKey),
            suppressed: Value(suppressedForInsert),
          ),
          onConflict: DoUpdate(
            (old) => RssArticlesCompanion(
              feedId: Value(feedId),
              guid: Value(entry.stableKey),
              title: Value(entry.title),
              link: Value(entry.link),
              summary: Value(entry.summary),
              publishedAt: Value(
                DateTime.fromMillisecondsSinceEpoch(
                  entry.publishedAtMs,
                  isUtc: true,
                ),
              ),
              fetchedAt: Value(DateTime.fromMillisecondsSinceEpoch(now)),
              imageBlobKey: Value(imageKey),
              suppressed: isBlocked
                  ? const Value(true)
                  : const Value.absent(),
            ),
          ),
        );
  }

  Future<String?> _downloadAndStoreImage(
    DataWriteContext ctx, {
    required String feedId,
    required String articleId,
    required String imageUrl,
  }) async {
    try {
      final imageUri = Uri.parse(imageUrl);
      AppDebugLog.provider(
        'rss: GET image article=$articleId ${AppDebugLog.safeHttpUri(imageUri)}',
      );
      final res = await _http.get(imageUri);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        AppDebugLog.provider(
          'rss: image article=$articleId status=${res.statusCode} '
          'bytes=${res.bodyBytes.length}',
        );
        return null;
      }
      final logicalKey = 'rss/$feedId/$articleId/image';
      final ref = await ctx.blobs.putBytes(
        res.bodyBytes,
        logicalKey: logicalKey,
      );
      AppDebugLog.provider(
        'rss: stored image article=$articleId bytes=${res.bodyBytes.length} '
        'blobKey=$logicalKey',
      );
      final mime =
          res.headers['content-type']?.split(';').first.trim() ?? 'image/jpeg';
      await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
            BlobMetadataCompanion.insert(
              blobKey: logicalKey,
              sha256: ref.storageKey.split('/').last,
              relativePath: ref.storageKey,
              bytes: res.bodyBytes.length,
              mimeType: Value(mime),
              capturedAt: DateTime.fromMillisecondsSinceEpoch(_nowMs()),
            ),
          );
      return logicalKey;
    } on Object catch (e, st) {
      AppDebugLog.providerFail('rss: image article=$articleId', e, st);
      return null;
    }
  }

  Future<void> _pruneFeedArticles(
    DataWriteContext ctx,
    String feedId,
    int maxArticles,
  ) async {
    if (maxArticles < 1) {
      return;
    }
    final rows =
        await (ctx.db.select(ctx.db.rssArticles)
              ..where((t) => t.feedId.equals(feedId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.publishedAt),
              ]))
            .get();
    final nonsuppressed = rows.where((r) => !r.suppressed).toList();
    if (nonsuppressed.length <= maxArticles) {
      return;
    }
    for (final a in nonsuppressed.sublist(maxArticles)) {
      await _deleteArticle(ctx, a);
    }
  }

  Future<void> _deleteArticle(DataWriteContext ctx, RssArticle a) async {
    final key = a.imageBlobKey;
    if (key != null && key.isNotEmpty) {
      final meta = await (ctx.db.select(
        ctx.db.blobMetadata,
      )..where((t) => t.blobKey.equals(key))).getSingleOrNull();
      if (meta != null) {
        await ctx.blobs.delete(BlobRef(meta.relativePath));
        await (ctx.db.delete(
          ctx.db.blobMetadata,
        )..where((t) => t.blobKey.equals(key))).go();
      }
    }
    await (ctx.db.delete(
      ctx.db.rssArticles,
    )..where((t) => t.id.equals(a.id))).go();
  }
}
