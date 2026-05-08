import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:waddle_display/curator/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/rss_article/rss_article_stack_slide_widget.dart';
import 'package:waddle_display/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

Future<void> _insertFeed(AppDatabase db) async {
  await db.into(db.rssFeedSources).insert(
        RssFeedSourcesCompanion.insert(
          id: 'feed_t',
          url: 'http://test.local/feed.xml',
          category: const Value('test'),
          title: const Value('Test Feed'),
        ),
      );
}

Future<void> _insertArticle(
  AppDatabase db, {
  required String id,
  required String title,
  String summary = 'Summary text.',
  String link = 'http://test.local/story',
}) async {
  await db.into(db.rssArticles).insert(
        RssArticlesCompanion.insert(
          id: id,
          feedId: 'feed_t',
          guid: 'guid_$id',
          title: title,
          link: link,
          summary: Value(summary),
          publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
          fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
}

void main() {
  testWidgets('shows two curated articles with two QR codes when links set', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertFeed(db);
    await _insertArticle(
      db,
      id: 'top',
      title: 'Top headline',
      summary: 'Top body.',
      link: 'https://news.example/top',
    );
    await _insertArticle(
      db,
      id: 'bottom',
      title: 'Bottom headline',
      summary: 'Bottom body.',
      link: 'https://news.example/bottom',
    );

    final slide = ResolvedSlide(
      screenId: 'news_stack',
      dwellMs: 12000,
      layoutJson: '{}',
      randomChoices: const {
        'main_rss_article_stack_0': 'top',
        'main_rss_article_stack_1': 'bottom',
      },
    );
    const spec = ParsedWidgetSpec(
      type: 'rss_article_stack',
      slot: 'main',
      config: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 560,
            child: RssArticleStackSlideWidget(
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
    expect(find.text('Top headline'), findsOneWidget);
    expect(find.text('Bottom headline'), findsOneWidget);
    expect(find.text('Test Feed'), findsNWidgets(2));
    expect(find.text('Top body.'), findsOneWidget);
    expect(find.text('Bottom body.'), findsOneWidget);
    expect(find.byType(QrImageView), findsNWidgets(2));
    final qrWidgets = tester.widgetList<QrImageView>(find.byType(QrImageView));
    for (final qr in qrWidgets) {
      expect(qr.padding, isA<EdgeInsets>());
      expect(qr.padding.left, greaterThan(0));
    }
    expect(find.byKey(const Key('rss_article_stack_row_0')), findsOneWidget);
    expect(find.byKey(const Key('rss_article_stack_row_1')), findsOneWidget);
    final topImage = tester.getTopLeft(
      find.byKey(const ValueKey<String>('rss_article_stack_image_0')),
    );
    final topTitle = tester.getTopLeft(find.text('Top headline'));
    final bottomImage = tester.getTopLeft(
      find.byKey(const ValueKey<String>('rss_article_stack_image_1')),
    );
    final bottomTitle = tester.getTopLeft(find.text('Bottom headline'));
    expect(topImage.dx, lessThan(topTitle.dx));
    expect(bottomImage.dx, lessThan(bottomTitle.dx));

    await db.close();
  });

  testWidgets('no articles shows placeholder', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    var reported = 0;
    final slide = ResolvedSlide(
      screenId: 'news_stack',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'rss_article_stack',
      slot: 'main',
      config: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: RssArticleStackSlideWidget(
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

  testWidgets('second slot empty shows placeholder row', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertFeed(db);
    await _insertArticle(db, id: 'only', title: 'Solo headline');

    final slide = ResolvedSlide(
      screenId: 'news_stack',
      dwellMs: 8000,
      layoutJson: '{}',
      randomChoices: const {
        'main_rss_article_stack_0': 'only',
      },
    );
    const spec = ParsedWidgetSpec(
      type: 'rss_article_stack',
      slot: 'main',
      config: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 400,
            child: RssArticleStackSlideWidget(
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
    expect(find.text('Solo headline'), findsOneWidget);
    expect(find.text('No article for this slot'), findsOneWidget);
    await db.close();
  });
}
