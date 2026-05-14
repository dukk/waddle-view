import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_data_providers/news_rss/rss_news_data_provider.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

const _fourItemRss = '''
<?xml version="1.0"?>
<rss version="2.0">
<channel>
<title>Source</title>
<link>http://ch</link>
<item>
  <title>Old</title>
  <link>http://o</link>
  <guid>1</guid>
  <pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
  <enclosure url="http://test.local/old.png" type="image/png" length="1"/>
</item>
<item>
  <title>B</title>
  <link>http://b</link>
  <guid>2</guid>
  <pubDate>Tue, 02 Jan 2024 00:00:00 GMT</pubDate>
  <enclosure url="http://test.local/pic.png" type="image/png" length="2"/>
</item>
<item>
  <title>C</title>
  <link>http://c</link>
  <guid>3</guid>
  <pubDate>Wed, 03 Jan 2024 00:00:00 GMT</pubDate>
</item>
<item>
  <title>It\u2019s Newest</title>
  <link>http://n</link>
  <guid>4</guid>
  <pubDate>Thu, 04 Jan 2024 00:00:00 GMT</pubDate>
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
        if (url.endsWith('.png')) 'content-type': 'image/png',
        if (url.contains('/feed')) 'content-type': 'application/rss+xml',
      },
    );
  }
}

void main() {
  test('RssNewsDataProvider default client and clock', () {
    final p = RssNewsDataProvider();
    expect(p.id, 'news_rss');
  });

  test('collect upserts articles, downloads image, trims to maxArticles', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'news_rss',
            providerType: 'news_rss',
            pollSeconds: const Value(1),
          ),
        );
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'feed1',
            url: 'http://test.local/feed.xml',
            category: const Value('tech'),
            pollSeconds: const Value(1),
            maxArticles: const Value(3),
            enabled: const Value(true),
          ),
        );
    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, {});
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );
    final pngHead = [0x89, 0x50, 0x4e, 0x47];
    final httpClient = _MapHttp({
      'http://test.local/feed.xml': utf8.encode(_fourItemRss),
      'http://test.local/old.png': pngHead,
      'http://test.local/pic.png': pngHead,
    });
    await RssNewsDataProvider(
      httpClient: httpClient,
      nowMs: () => 1_000_000,
    ).collect(ctx);

    final rows = await (db.select(db.rssArticles)
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)]))
        .get();
    expect(rows.length, 3);
    expect(rows.first.title, 'It\u2019s Newest');
    final blobs = await db.select(db.blobMetadata).get();
    expect(
      blobs.length,
      1,
      reason: 'prune removes the oldest item and its image; one image remains',
    );
    await db.close();
  });

  test('collect skips feed when HTTP status is not 200', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'news_rss',
            providerType: 'news_rss',
          ),
        );
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'feed404',
            url: 'http://test.local/missing.xml',
            pollSeconds: const Value(1),
            maxArticles: const Value(5),
          ),
        );
    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, {});
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );
    final client = _FixedStatusClient(404);
    await RssNewsDataProvider(httpClient: client, nowMs: () => 1).collect(ctx);
    final n = await ctx.db.select(ctx.db.rssArticles).get();
    expect(n, isEmpty);
    await db.close();
  });

  test('collect keeps article when image download throws', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(id: 'news_rss', providerType: 'news_rss'),
        );
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'feed2',
            url: 'http://test.local/feed.xml',
            pollSeconds: const Value(1),
            maxArticles: const Value(10),
          ),
        );
    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, {});
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );
    final oneItem = r'''
<?xml version="1.0"?><rss version="2.0"><channel><title>X</title><link>http://x</link>
<item><title>T</title><link>http://t</link><guid>g</guid>
<pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
<enclosure url="http://test.local/bad.png" type="image/png" length="1"/>
</item></channel></rss>''';
    final client = _ThrowOnImagePng(
      map: {
        'http://test.local/feed.xml': utf8.encode(oneItem),
      },
    );
    await RssNewsDataProvider(httpClient: client, nowMs: () => 1).collect(ctx);
    final rows = await ctx.db.select(ctx.db.rssArticles).get();
    expect(rows.length, 1);
    expect(rows.single.imageBlobKey, isNull);
    await db.close();
  });

  test('collect skips feed when within poll interval', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(id: 'news_rss', providerType: 'news_rss'),
        );
    const last = 1_000_000;
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'f1',
            url: 'http://test.local/feed.xml',
            pollSeconds: const Value(60),
            lastFetchedAt: Value(DateTime.fromMillisecondsSinceEpoch(last)),
            maxArticles: const Value(5),
          ),
        );
    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, {});
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );
    var sends = 0;
    final client = _CountingClient(() => sends++);
    await RssNewsDataProvider(
      httpClient: client,
      nowMs: () => last + 30_000,
    ).collect(ctx);
    expect(sends, 0);
    await db.close();
  });

  test('collect continues when feed GET throws', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(id: 'news_rss', providerType: 'news_rss'),
        );
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'f1',
            url: 'http://test.local/feed.xml',
            pollSeconds: const Value(1),
            maxArticles: const Value(5),
          ),
        );
    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, {});
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );
    await RssNewsDataProvider(
      httpClient: _ThrowClient(),
      nowMs: () => 1,
    ).collect(ctx);
    final n = await ctx.db.select(ctx.db.rssArticles).get();
    expect(n, isEmpty);
    await db.close();
  });
}

class _FixedStatusClient extends http.BaseClient {
  _FixedStatusClient(this._code);
  final int _code;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(const []),
      _code,
    );
  }
}

class _ThrowOnImagePng extends http.BaseClient {
  _ThrowOnImagePng({required this.map});
  final Map<String, List<int>> map;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url.toString();
    if (u.contains('bad.png')) {
      throw StateError('network');
    }
    final bytes = map[u] ?? utf8.encode('');
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([bytes]),
      200,
    );
  }
}

class _CountingClient extends http.BaseClient {
  _CountingClient(this.onSend);
  final void Function() onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onSend();
    return http.StreamedResponse(Stream<List<int>>.fromIterable([[]]), 200);
  }
}

class _ThrowClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw StateError('network');
  }
}
