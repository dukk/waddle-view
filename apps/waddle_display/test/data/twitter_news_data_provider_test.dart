import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_data_providers/news_twitter/twitter_api_client.dart';
import 'package:waddle_data_providers/news_twitter/twitter_news_data_provider.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/config/twitter_kv.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/news/social_news_post.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

class _FakeTwitterApi extends TwitterApiClient {
  _FakeTwitterApi(this.posts);

  final List<SocialNewsPost> posts;

  @override
  Future<List<SocialNewsPost>> fetchUserTweets({
    required String bearerToken,
    required String userId,
    void Function(String message)? log,
  }) async =>
      posts;
}

void main() {
  test('TwitterNewsDataProvider upserts into news table', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    await secrets.write(twitterAccessTokenSecret('acct1'), 'token');
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultNewsTwitterIntegrationId,
            integrationType: 'news_twitter',
            enabled: const Value(true),
            pollSeconds: const Value(60),
          ),
        );
    await db.into(db.integrationAccounts).insert(
          IntegrationAccountsCompanion.insert(
            id: 'acct1',
            accountType: kIntegrationAccountTypeTwitter,
            createdAtMs: 1,
          ),
        );
    await db.into(db.interestsTwitterSources).insert(
          InterestsTwitterSourcesCompanion.insert(
            id: 'elon',
            targetType: 'user',
            targetId: '44196397',
            accountId: 'acct1',
            pollSeconds: const Value(60),
            maxArticles: const Value(5),
          ),
        );

    final provider = TwitterNewsDataProvider(
      api: _FakeTwitterApi([
        SocialNewsPost(
          id: 'tw1',
          text: 'Tweet body',
          link: 'https://x.com/i/web/status/tw1',
          createdAtMs: DateTime.utc(2024, 1, 1).millisecondsSinceEpoch,
        ),
      ]),
      nowMs: () => DateTime.utc(2024, 6, 1).millisecondsSinceEpoch,
    );
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await provider.collect(ctx);

    final rows = await db.select(db.news).get();
    expect(rows, hasLength(1));
    expect(rows.single.sourceType, kNewsSourceTypeTwitter);
    expect(rows.single.sourceId, 'elon');
    await db.close();
  });
}
