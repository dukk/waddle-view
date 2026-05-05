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
    'news curation requires a photo by default but can be overridden',
    (tester) async {
      final db = openMemoryDatabase();
      var closed = false;
      addTearDown(() async {
        if (!closed) {
          await _disposeWidgetAndDb(tester: tester, db: db);
        }
      });
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

      await _disposeWidget(tester);

      final blobs = FakeBlobStore();
      final blobRef = await blobs.putBytes(
        <int>[137, 80, 78, 71, 13, 10, 26, 10],
        logicalKey: 'rss_img',
      );
      await db.delete(db.rssArticles).go();
      await db.delete(db.rssFeedSources).go();
      await db.delete(db.blobMetadata).go();
      await db.into(db.rssFeedSources).insert(
            RssFeedSourcesCompanion.insert(
              id: 'feed_t',
              url: 'http://test.local/feed.xml',
              category: const Value('test'),
            ),
          );
      await db.into(db.rssArticles).insert(
            RssArticlesCompanion.insert(
              id: 'article_t_2',
              feedId: 'feed_t',
              guid: 'g2',
              title: 'Breaking: widgets work',
              link: 'http://test.local/a',
              summary: const Value('Short summary for rendering check.'),
              publishedAt: 2,
              fetchedAt: 2,
              imageBlobKey: Value(blobRef.storageKey),
            ),
          );
      await db.into(db.blobMetadata).insert(
            BlobMetadataCompanion.insert(
              blobKey: blobRef.storageKey,
              sha256: 'demo',
              relativePath: blobRef.storageKey,
              bytes: 8,
              capturedAt: 2,
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

      await _disposeWidgetAndDb(tester: tester, db: db);
      closed = true;
    },
  );
}

Future<File> _tempKeyFile(String value) async {
  final file = File('${Directory.systemTemp.path}/wv_rotator_test_api.key');
  await file.writeAsString('$value\n', flush: true);
  return file;
}

Future<void> _disposeWidgetAndDb({
  required WidgetTester tester,
  required AppDatabase db,
}) async {
  await _disposeWidget(tester);
  await db.close();
}

Future<void> _disposeWidget(WidgetTester tester) async {
  // Unmount timer-driven widgets before closing Drift.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
