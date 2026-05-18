import 'package:drift/drift.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/news/news_article_id.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/secret_store.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/net/http_debug_uri.dart';
import 'package:http/http.dart' as http;

import 'facebook_graph_client.dart';

const String kFacebookNewsProviderId = 'news_facebook';

class FacebookNewsDataProvider implements IDataProvider {
  FacebookNewsDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
    FacebookGraphClient? graph,
  })  : _http = httpClient ?? http.Client(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _graph = graph ?? FacebookGraphClient(httpClient: httpClient);

  final http.Client _http;
  final int Function() _nowMs;
  final FacebookGraphClient _graph;

  @override
  String get id => kFacebookNewsProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting = await (ctx.db.select(ctx.db.integrations)
          ..where((t) => t.id.equals(kDefaultNewsFacebookIntegrationId)))
        .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      ctx.diagnostics.provider('facebook_news: skip (disabled)');
      return;
    }

    final now = _nowMs();
    final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);
    final sources = await (ctx.db.select(ctx.db.interestsFacebookSources)
          ..where((t) => t.enabled.equals(true)))
        .get();
    if (sources.isEmpty) {
      ctx.diagnostics.provider('facebook_news: collect skip (no enabled sources)');
      return;
    }
    ctx.diagnostics.provider(
      'facebook_news: collect enabledSources=${sources.length}',
    );

    for (final source in sources) {
      final last = source.lastFetchedAt;
      final due = last == null ||
          (now - last.millisecondsSinceEpoch) >= source.pollSeconds * 1000;
      if (!due) {
        ctx.diagnostics.provider(
          'facebook_news: skip source id=${source.id} (poll not due)',
        );
        continue;
      }
      final token = await _readAccessToken(ctx.secrets, source.accountId);
      if (token == null || token.isEmpty) {
        ctx.diagnostics.provider(
          'facebook_news: skip source id=${source.id} (no token for ${source.accountId})',
        );
        continue;
      }
      try {
        final posts = await _graph.fetchPageOrGroupPosts(
          accessToken: token,
          targetType: source.targetType,
          targetId: source.targetId,
          log: ctx.diagnostics.provider,
        );
        ctx.diagnostics.provider(
          'facebook_news: source id=${source.id} posts=${posts.length}',
        );
        for (final post in posts) {
          await _upsertArticle(
            ctx,
            source: source,
            post: post,
            now: now,
            rejectCtx: rejectCtx,
          );
        }
        await _pruneSourceArticles(ctx, source.id, source.maxArticles);
        await (ctx.db.update(ctx.db.interestsFacebookSources)
              ..where((t) => t.id.equals(source.id)))
            .write(
          InterestsFacebookSourcesCompanion(
            lastFetchedAt: Value(DateTime.fromMillisecondsSinceEpoch(now)),
            consecutiveFailures: const Value(0),
            nextRetryAt: const Value.absent(),
          ),
        );
      } on Object catch (e, st) {
        ctx.diagnostics.providerFail(
          'facebook_news: source id=${source.id}',
          e,
          st,
        );
      }
    }
  }

  Future<String?> _readAccessToken(SecretStore secrets, String accountId) async {
    final def = kIntegrationAccountTypes[kIntegrationAccountTypeFacebook];
    if (def == null) {
      return null;
    }
    return secrets.read(def.accessTokenSecretKey(accountId));
  }

  Future<void> _upsertArticle(
    DataWriteContext ctx, {
    required InterestsFacebookSource source,
    required FacebookFeedPost post,
    required int now,
    required RejectFilterContext rejectCtx,
  }) async {
    final articleId = newsArticleId(
      kNewsSourceTypeFacebook,
      source.id,
      post.id,
    );
    final existing = await (ctx.db.select(ctx.db.news)
          ..where((t) => t.id.equals(articleId)))
        .getSingleOrNull();
    var imageKey = existing?.imageBlobKey;
    if (post.fullPictureUrl != null &&
        post.fullPictureUrl!.isNotEmpty &&
        imageKey == null) {
      imageKey = await _downloadAndStoreImage(
        ctx,
        sourceId: source.id,
        articleId: articleId,
        imageUrl: post.fullPictureUrl!,
      );
    }

    final title = _titleFromPost(post);
    final summary = post.message.length > title.length
        ? post.message
        : null;
    final isBlocked = rejectCtx.isBlockedAny([title, summary]);
    final suppressedForInsert = (existing?.suppressed ?? false) || isBlocked;

    await ctx.db.into(ctx.db.news).insert(
          NewsCompanion.insert(
            id: articleId,
            sourceType: kNewsSourceTypeFacebook,
            sourceId: source.id,
            guid: post.id,
            title: title,
            link: post.permalinkUrl,
            summary: Value(summary),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(
              post.createdAtMs,
              isUtc: true,
            ),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(now),
            imageBlobKey: Value(imageKey),
            suppressed: Value(suppressedForInsert),
          ),
          onConflict: DoUpdate(
            (old) => NewsCompanion(
              sourceType: const Value(kNewsSourceTypeFacebook),
              sourceId: Value(source.id),
              guid: Value(post.id),
              title: Value(title),
              link: Value(post.permalinkUrl),
              summary: Value(summary),
              publishedAt: Value(
                DateTime.fromMillisecondsSinceEpoch(
                  post.createdAtMs,
                  isUtc: true,
                ),
              ),
              fetchedAt: Value(DateTime.fromMillisecondsSinceEpoch(now)),
              imageBlobKey: Value(imageKey),
              suppressed:
                  isBlocked ? const Value(true) : const Value.absent(),
            ),
          ),
        );
  }

  String _titleFromPost(FacebookFeedPost post) {
    final msg = post.message.trim();
    if (msg.isEmpty) {
      return 'Facebook post';
    }
    const maxLen = 200;
    if (msg.length <= maxLen) {
      return msg;
    }
    return '${msg.substring(0, maxLen - 1)}…';
  }

  Future<String?> _downloadAndStoreImage(
    DataWriteContext ctx, {
    required String sourceId,
    required String articleId,
    required String imageUrl,
  }) async {
    try {
      final imageUri = Uri.parse(imageUrl);
      ctx.diagnostics.provider(
        'facebook_news: GET image article=$articleId '
        '${safeHttpUriForLog(imageUri)}',
      );
      final res = await _http.get(imageUri);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        return null;
      }
      final logicalKey = 'facebook/$sourceId/$articleId/image';
      final ref = await ctx.blobs.putBytes(
        res.bodyBytes,
        logicalKey: logicalKey,
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
      ctx.diagnostics.providerFail(
        'facebook_news: image article=$articleId',
        e,
        st,
      );
      return null;
    }
  }

  Future<void> _pruneSourceArticles(
    DataWriteContext ctx,
    String sourceId,
    int maxArticles,
  ) async {
    if (maxArticles < 1) {
      return;
    }
    final rows = await (ctx.db.select(ctx.db.news)
          ..where(
            (t) => t.sourceType.equals(kNewsSourceTypeFacebook) &
                t.sourceId.equals(sourceId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)]))
        .get();
    final nonsuppressed = rows.where((r) => !r.suppressed).toList();
    if (nonsuppressed.length <= maxArticles) {
      return;
    }
    for (final a in nonsuppressed.sublist(maxArticles)) {
      await _deleteArticle(ctx, a);
    }
  }

  Future<void> _deleteArticle(DataWriteContext ctx, NewsArticle a) async {
    final key = a.imageBlobKey;
    if (key != null && key.isNotEmpty) {
      final meta = await (ctx.db.select(ctx.db.blobMetadata)
            ..where((t) => t.blobKey.equals(key)))
          .getSingleOrNull();
      if (meta != null) {
        await ctx.blobs.delete(BlobRef(meta.relativePath));
        await (ctx.db.delete(ctx.db.blobMetadata)
              ..where((t) => t.blobKey.equals(key)))
            .go();
      }
    }
    await (ctx.db.delete(ctx.db.news)..where((t) => t.id.equals(a.id))).go();
  }
}
