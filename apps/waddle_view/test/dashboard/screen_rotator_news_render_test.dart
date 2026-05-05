import 'package:drift/drift.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/dashboard/screen_rotator.dart';
import 'package:waddle_view/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  testWidgets(
    'news screen is excluded by default when article photo is missing',
    (tester) async {
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
                adminBaseUrl: 'http://127.0.0.1:8787',
                setupPasswordFile: await _tempKeyFile('x'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No display screens enabled'), findsOneWidget);
      expect(find.text('Breaking: widgets work'), findsNothing);

      await db.close();
    },
  );

  testWidgets('news screen renders rss article content in rotator', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    final blobRef = await blobs.putBytes(
      <int>[137, 80, 78, 71, 13, 10, 26, 10],
      logicalKey: 'rss_img',
    );

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
            imageBlobKey: Value(blobRef.storageKey),
          ),
        );
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: blobRef.storageKey,
            sha256: 'demo',
            relativePath: blobRef.storageKey,
            bytes: 8,
            capturedAt: 1,
          ),
        );
    await db.into(db.dashboardKv).insertOnConflictUpdate(
          DashboardKvCompanion.insert(
            key: 'curator.news.require_photo_for_curation',
            value: 'false',
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
                blobs: blobs,
              localRestBaseUrl: 'http://127.0.0.1:8787',
              adminBaseUrl: 'http://127.0.0.1:8787',
              setupPasswordFile: await _tempKeyFile('x'),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Breaking: widgets work'), findsOneWidget);

    await db.close();
  });
}

Future<File> _tempKeyFile(String value) async {
  final dir = await Directory.systemTemp.createTemp('wv_rotator_test_');
  final file = File('${dir.path}/waddle_api.key');
  await file.writeAsString('$value\n', flush: true);
  return file;
}
