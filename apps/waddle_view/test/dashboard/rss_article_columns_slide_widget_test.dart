import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/curator/screen_program_curator.dart';
import 'package:waddle_view/dashboard/rss_article_columns_slide_widget.dart';
import 'package:waddle_view/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

Future<void> _insertFeed(AppDatabase db) async {
  await db.into(db.rssFeedSources).insert(
        RssFeedSourcesCompanion.insert(
          id: 'feed_t',
          url: 'http://test.local/feed.xml',
          category: const Value('test'),
        ),
      );
}

Future<void> _insertArticle(
  AppDatabase db, {
  required String id,
  required String title,
  String summary = 'Summary text.',
}) async {
  await db.into(db.rssArticles).insert(
        RssArticlesCompanion.insert(
          id: id,
          feedId: 'feed_t',
          guid: 'guid_$id',
          title: title,
          link: 'http://test.local/$id',
          summary: Value(summary),
          publishedAt: 1,
          fetchedAt: 1,
        ),
      );
}

void main() {
  testWidgets('shows three curated headlines in columns', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertFeed(db);
    await _insertArticle(db, id: 'a1', title: 'First headline');
    await _insertArticle(db, id: 'a2', title: 'Second headline');
    await _insertArticle(db, id: 'a3', title: 'Third headline');

    final slide = ResolvedSlide(
      screenId: 'news_columns',
      dwellMs: 12000,
      layoutJson: '{}',
      randomChoices: const {
        'main_rss_article_columns_0': 'a1',
        'main_rss_article_columns_1': 'a2',
        'main_rss_article_columns_2': 'a3',
      },
    );
    const spec = ParsedWidgetSpec(
      type: 'rss_article_columns',
      slot: 'main',
      config: {'columnCount': 3},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 500,
            child: RssArticleColumnsSlideWidget(
              db: db,
              blobs: FakeBlobStore(),
              slide: slide,
              spec: spec,
              theme: ThemeData.light(),
              onReportDesiredDwell: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First headline'), findsOneWidget);
    expect(find.text('Second headline'), findsOneWidget);
    expect(find.text('Third headline'), findsOneWidget);
    await db.close();
  });

  testWidgets('no articles shows placeholder', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    var reported = 0;
    final slide = ResolvedSlide(
      screenId: 'news_columns',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'rss_article_columns',
      slot: 'main',
      config: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: RssArticleColumnsSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
            onReportDesiredDwell: (ms) => reported = ms,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No news articles yet'), findsOneWidget);
    expect(reported, greaterThan(0));
    await db.close();
  });
}
