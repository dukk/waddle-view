import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_data_providers/news_linkedin/linkedin_api_client.dart';
import 'package:waddle_data_providers/news_linkedin/linkedin_news_data_provider.dart';
import 'package:waddle_shared/config/linkedin_kv.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/news/social_news_post.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

class _FakeLinkedInApi extends LinkedInApiClient {
  _FakeLinkedInApi(this.posts);

  final List<SocialNewsPost> posts;

  @override
  Future<List<SocialNewsPost>> fetchAuthorPosts({
    required String accessToken,
    required String targetType,
    required String targetId,
    void Function(String message)? log,
  }) async =>
      posts;
}

void main() {
  test('LinkedInNewsDataProvider upserts into news table', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    await secrets.write(linkedInAccessTokenSecret('acct1'), 'token');
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultNewsLinkedinIntegrationId,
            integrationType: 'news_linkedin',
            enabled: const Value(true),
            pollSeconds: const Value(60),
          ),
        );
    await db.into(db.integrationAccounts).insert(
          IntegrationAccountsCompanion.insert(
            id: 'acct1',
            accountType: kIntegrationAccountTypeLinkedin,
            createdAtMs: 1,
          ),
        );
    await db.into(db.interestsLinkedinSources).insert(
          InterestsLinkedinSourcesCompanion.insert(
            id: 'acme',
            targetType: 'organization',
            targetId: '12345',
            accountId: 'acct1',
            pollSeconds: const Value(60),
            maxArticles: const Value(5),
          ),
        );

    final provider = LinkedInNewsDataProvider(
      api: _FakeLinkedInApi([
        SocialNewsPost(
          id: 'urn:li:share:1',
          text: 'LinkedIn update',
          link: 'https://www.linkedin.com/feed/update/urn:li:share:1',
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
    expect(rows.single.sourceType, kNewsSourceTypeLinkedin);
    expect(rows.single.sourceId, 'acme');
    await db.close();
  });
}
