import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/news/social_news_collect.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

import 'twitter_api_client.dart';

const String kTwitterNewsProviderId = 'news_twitter';

class TwitterNewsDataProvider implements IDataProvider {
  TwitterNewsDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
    TwitterApiClient? api,
  })  : _http = httpClient ?? http.Client(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _api = api ?? TwitterApiClient(httpClient: httpClient);

  final http.Client _http;
  final int Function() _nowMs;
  final TwitterApiClient _api;

  @override
  String get id => kTwitterNewsProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting = await (ctx.db.select(ctx.db.integrations)
          ..where((t) => t.id.equals(kDefaultNewsTwitterIntegrationId)))
        .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      ctx.diagnostics.provider('twitter_news: skip (disabled)');
      return;
    }

    final now = _nowMs();
    final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);
    final sources = await (ctx.db.select(ctx.db.interestsTwitterSources)
          ..where((t) => t.enabled.equals(true)))
        .get();
    if (sources.isEmpty) {
      ctx.diagnostics.provider('twitter_news: collect skip (no enabled sources)');
      return;
    }
    ctx.diagnostics.provider(
      'twitter_news: collect enabledSources=${sources.length}',
    );

    for (final source in sources) {
      if (!_isDue(source, now)) {
        ctx.diagnostics.provider(
          'twitter_news: skip source id=${source.id} (poll not due)',
        );
        continue;
      }
      if (source.targetType != 'user') {
        ctx.diagnostics.provider(
          'twitter_news: skip source id=${source.id} (unsupported target_type)',
        );
        continue;
      }
      final token = await _readAccessToken(ctx.secrets, source.accountId);
      if (token == null || token.isEmpty) {
        ctx.diagnostics.provider(
          'twitter_news: skip source id=${source.id} (no token)',
        );
        continue;
      }
      try {
        final posts = await _api.fetchUserTweets(
          bearerToken: token,
          userId: source.targetId,
          log: ctx.diagnostics.provider,
        );
        ctx.diagnostics.provider(
          'twitter_news: source id=${source.id} posts=${posts.length}',
        );
        for (final post in posts) {
          await upsertSocialNewsPost(
            ctx,
            sourceType: kNewsSourceTypeTwitter,
            sourceId: source.id,
            post: post,
            nowMs: now,
            rejectCtx: rejectCtx,
            httpClient: _http,
            imageBlobPrefix: 'twitter',
            fallbackTitle: 'Post',
          );
        }
        await pruneSocialNewsArticles(
          ctx,
          sourceType: kNewsSourceTypeTwitter,
          sourceId: source.id,
          maxArticles: source.maxArticles,
        );
        await _markFetched(ctx, source.id, now);
      } on Object catch (e, st) {
        ctx.diagnostics.providerFail('twitter_news: source id=${source.id}', e, st);
      }
    }
  }

  bool _isDue(InterestsTwitterSource source, int now) {
    final last = source.lastFetchedAt;
    return last == null ||
        (now - last.millisecondsSinceEpoch) >= source.pollSeconds * 1000;
  }

  Future<void> _markFetched(DataWriteContext ctx, String sourceId, int now) async {
    await (ctx.db.update(ctx.db.interestsTwitterSources)
          ..where((t) => t.id.equals(sourceId)))
        .write(
      InterestsTwitterSourcesCompanion(
        lastFetchedAt: Value(DateTime.fromMillisecondsSinceEpoch(now)),
        consecutiveFailures: const Value(0),
        nextRetryAt: const Value.absent(),
      ),
    );
  }

  Future<String?> _readAccessToken(SecretStore secrets, String accountId) async {
    final def = kIntegrationAccountTypes[kIntegrationAccountTypeTwitter];
    if (def == null) {
      return null;
    }
    return secrets.read(def.accessTokenSecretKey(accountId));
  }
}
