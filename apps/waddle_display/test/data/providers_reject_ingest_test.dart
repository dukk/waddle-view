import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_data_providers/news_rss/rss_news_data_provider.dart';
import 'package:waddle_data_providers/joke_openai/joke_data_provider.dart';
import 'package:waddle_data_providers/trivia_openai/trivia_data_provider.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/reject_term_repository.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

const _rssBadAndGood = '''
<?xml version="1.0"?>
<rss version="2.0">
<channel>
<title>Source</title>
<link>http://ch</link>
<item>
  <title>Watch this damn news</title>
  <link>http://a</link>
  <guid>1</guid>
  <pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
</item>
<item>
  <title>Local park gets new playground</title>
  <link>http://b</link>
  <guid>2</guid>
  <pubDate>Tue, 02 Jan 2024 00:00:00 GMT</pubDate>
</item>
</channel>
</rss>
''';

class _MapHttp extends http.BaseClient {
  _MapHttp(this._map);
  final Map<String, List<int>> _map;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    final bytes = _map[url] ?? utf8.encode('');
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([bytes]),
      200,
      headers: {
        if (url.contains('/feed')) 'content-type': 'application/rss+xml',
      },
    );
  }
}

Future<DataWriteContextImpl> _newCtx(AppDatabase db) async {
  final secrets = InMemorySecretStore();
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: FakeBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

void main() {
  test('RSS provider marks suppressed when title matches a block term',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.delete(db.rejectTerms).go();
    await RejectTermRepository(db).upsert(
      RejectTermInput.parse(rawTerm: 'damn', rawAction: 'block')!,
    );

    await db.into(db.integrations).insert(
      IntegrationsCompanion.insert(
        id: kDefaultNewsRssIntegrationId,
        integrationType: 'news_rss',
        pollSeconds: const Value(1),
      ),
    );
    await db.into(db.interestsRssFeeds).insert(
      InterestsRssFeedsCompanion.insert(
        id: 'feed1',
        url: 'http://test.local/feed.xml',
        pollSeconds: const Value(1),
        maxArticles: const Value(5),
        enabled: const Value(true),
      ),
    );
    final ctx = await _newCtx(db);
    final client = _MapHttp({
      'http://test.local/feed.xml': utf8.encode(_rssBadAndGood),
    });
    await RssNewsDataProvider(httpClient: client, nowMs: () => 1).collect(ctx);

    final rows = await db.select(db.rssArticles).get();
    expect(rows.length, 2);
    final bad = rows.firstWhere((r) => r.title.contains('damn'));
    final good = rows.firstWhere((r) => !r.title.contains('damn'));
    expect(bad.suppressed, isTrue);
    expect(good.suppressed, isFalse);

    await db.close();
  });

  test(
    'RSS provider leaves suppressed=false when only censor terms match',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      await db.delete(db.rejectTerms).go();
      await RejectTermRepository(db).upsert(
        RejectTermInput.parse(rawTerm: 'damn', rawAction: 'censor')!,
      );

      await db.into(db.integrations).insert(
        IntegrationsCompanion.insert(
          id: kDefaultNewsRssIntegrationId,
          integrationType: 'news_rss',
          pollSeconds: const Value(1),
        ),
      );
      await db.into(db.interestsRssFeeds).insert(
        InterestsRssFeedsCompanion.insert(
          id: 'feed1',
          url: 'http://test.local/feed.xml',
          pollSeconds: const Value(1),
          maxArticles: const Value(5),
          enabled: const Value(true),
        ),
      );
      final ctx = await _newCtx(db);
      final client = _MapHttp({
        'http://test.local/feed.xml': utf8.encode(_rssBadAndGood),
      });
      await RssNewsDataProvider(httpClient: client, nowMs: () => 1)
          .collect(ctx);
      final rows = await db.select(db.rssArticles).get();
      expect(rows.every((r) => r.suppressed == false), isTrue);
      await db.close();
    },
  );

  test('JokeDataProvider class is plain Dart constructor (smoke)', () {
    final p = JokeDataProvider();
    expect(p.id, 'joke_openai');
  });

  test('TriviaDataProvider class is plain Dart constructor (smoke)', () {
    final p = TriviaDataProvider();
    expect(p.id, 'trivia_openai');
  });
}
