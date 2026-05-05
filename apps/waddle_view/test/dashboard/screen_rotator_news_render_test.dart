import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/dashboard/screen_rotator.dart';
import 'package:waddle_view/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  testWidgets('news screen renders rss article content in rotator', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await db.into(db.screenDefinitions).insert(
          ScreenDefinitionsCompanion.insert(
            id: 'news',
            name: 'News',
            layoutJson: Value(
              '{"v":1,"layout":"single","widgets":[{"type":"rss_article","slot":"main","config":{}}]}',
            ),
            dwellMs: Value(60000),
          ),
        );
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'feed_t',
            url: 'http://test.local/feed.xml',
            category: const Value('test'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'article_t_1',
            feedId: 'feed_t',
            guid: 'g1',
            title: 'Breaking: widgets work',
            link: 'http://test.local/a',
            summary: const Value('Short summary for rendering check.'),
            publishedAt: 1,
            fetchedAt: 1,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 700,
            child: ScreenRotator(
              db: db,
              blobs: FakeBlobStore(),
              localRestBaseUrl: 'http://127.0.0.1:8787',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Breaking: widgets work'), findsOneWidget);

    await db.close();
  });
}
