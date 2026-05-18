import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_data_providers/news_facebook/facebook_graph_client.dart';
import 'package:waddle_data_providers/news_facebook/facebook_news_data_provider.dart';
import 'package:waddle_shared/config/facebook_kv.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

class _FakeGraph extends FacebookGraphClient {
  _FakeGraph(this.posts);

  final List<FacebookFeedPost> posts;

  @override
  Future<List<FacebookFeedPost>> fetchPageOrGroupPosts({
    required String accessToken,
    required String targetType,
    required String targetId,
    void Function(String message)? log,
  }) async =>
      posts;
}

void main() {
  test('FacebookNewsDataProvider upserts into news table', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    await secrets.write(
      facebookAccessTokenSecret('acct1'),
      'token',
    );
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultNewsFacebookIntegrationId,
            integrationType: 'news_facebook',
            enabled: const Value(true),
            pollSeconds: const Value(60),
          ),
        );
    await db.into(db.integrationAccounts).insert(
          IntegrationAccountsCompanion.insert(
            id: 'acct1',
            accountType: kIntegrationAccountTypeFacebook,
            createdAtMs: 1,
          ),
        );
    await db.into(db.interestsFacebookSources).insert(
          InterestsFacebookSourcesCompanion.insert(
            id: 'my_page',
            targetType: 'page',
            targetId: '12345',
            accountId: 'acct1',
            pollSeconds: const Value(60),
            maxArticles: const Value(5),
          ),
        );

    final provider = FacebookNewsDataProvider(
      graph: _FakeGraph([
        FacebookFeedPost(
          id: 'post1',
          message: 'Status update',
          permalinkUrl: 'https://www.facebook.com/post1',
          createdAtMs: DateTime.utc(2024, 1, 1).millisecondsSinceEpoch,
        ),
      ]),
      nowMs: () => DateTime.utc(2024, 6, 1).millisecondsSinceEpoch,
    );
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );
    await provider.collect(ctx);

    final rows = await db.select(db.news).get();
    expect(rows, hasLength(1));
    expect(rows.single.sourceType, kNewsSourceTypeFacebook);
    expect(rows.single.sourceId, 'my_page');
    expect(rows.single.title, 'Status update');
    await db.close();
  });
}
