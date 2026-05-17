import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/news/news_slide_timing.dart';
import 'package:waddle_display/display/screens/news/news_slide_widget.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

/// Minimal valid PNG (1×1).
final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Future<void> _insertFeedAndArticle(
  AppDatabase db, {
  required String summary,
  String? imageBlobKey,
  String link = 'http://test.local/a',
}) async {
  await db.into(db.interestsRssFeeds).insert(
        InterestsRssFeedsCompanion.insert(
          id: 'feed_t',
          url: 'http://test.local/feed.xml',
          category: const Value('test'),
          title: const Value('Test Feed'),
        ),
      );
  await db.into(db.rssArticles).insert(
        RssArticlesCompanion.insert(
          id: 'article_t_1',
          feedId: 'feed_t',
          guid: 'g1',
          title: 'Breaking: widgets work',
          link: link,
          summary: Value(summary),
          publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
          fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          imageBlobKey: Value(imageBlobKey),
        ),
      );
}

Future<void> _insertArticle(
  AppDatabase db, {
  required String id,
  required String title,
  int publishedAt = 1,
  String? imageBlobKey,
}) async {
  await db.into(db.rssArticles).insert(
        RssArticlesCompanion.insert(
          id: id,
          feedId: 'feed_t',
          guid: 'guid_$id',
          title: title,
          link: 'http://test.local/$id',
          summary: const Value('Summary'),
          publishedAt: DateTime.fromMillisecondsSinceEpoch(publishedAt),
          fetchedAt: DateTime.fromMillisecondsSinceEpoch(publishedAt),
          imageBlobKey: Value(imageBlobKey),
        ),
      );
}

void main() {
  testWidgets('no articles shows placeholder', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    var reported = 0;
    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'news',
      slot: 'main',
      config: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: NewsSlideWidget(
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
    expect(reported, 0);
    await db.close();
  });

  testWidgets('uses curated article id instead of best-ranked article', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    final highRef = await blobs.putBytes(
      List<int>.filled(8000, 1),
      logicalKey: 'rss/big',
    );
    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: 'feed_t',
            url: 'http://test.local/feed.xml',
            category: const Value('test'),
            title: const Value('Test Feed'),
          ),
        );
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'rss/big',
            sha256: highRef.storageKey,
            relativePath: highRef.storageKey,
            bytes: 8000,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await _insertArticle(
      db,
      id: 'article_best',
      title: 'Highest quality image wins without curation',
      publishedAt: 100,
      imageBlobKey: 'rss/big',
    );
    await _insertArticle(
      db,
      id: 'article_curated',
      title: 'Curated lesser headline',
      publishedAt: 50,
    );

    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 5000,
      layoutJson: '{}',
      randomChoices: const {'main_news': 'article_curated'},
    );
    const spec = ParsedWidgetSpec(
      type: 'news',
      slot: 'main',
      config: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: NewsSlideWidget(
            db: db,
            blobs: blobs,
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
            onReportDesiredDwell: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Curated lesser headline'), findsOneWidget);
    expect(find.text('Test Feed'), findsOneWidget);
    expect(
      find.text('Highest quality image wins without curation'),
      findsNothing,
    );
    await db.close();
  });

  testWidgets('imageOnRight places image panel to the right of text', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    final ref = await blobs.putBytes(_tinyPng, logicalKey: 'rss/feed_t/layout');
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'rss/feed_t/layout',
            sha256: ref.storageKey,
            relativePath: ref.storageKey,
            bytes: _tinyPng.length,
            mimeType: const Value('image/png'),
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await _insertFeedAndArticle(
      db,
      summary: 'Body text for layout.',
      imageBlobKey: 'rss/feed_t/layout',
    );
    final slide = ResolvedSlide(
      screenId: 'news_right',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'news',
      slot: 'main',
      config: {'imageOnRight': true},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 800,
              height: 400,
              child: NewsSlideWidget(
                db: db,
                blobs: blobs,
                slide: slide,
                spec: spec,
                theme: ThemeData.light(),
                onReportDesiredDwell: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final imageBox = tester.getRect(
      find.byKey(const Key('rss_article_image_panel')),
    );
    final textBox = tester.getRect(
      find.byKey(const Key('rss_article_text_column')),
    );
    expect(imageBox.left, greaterThan(textBox.left));
    await db.close();
  });

  testWidgets('short summary reports max of base dwell and minRead', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertFeedAndArticle(db, summary: 'Brief update.');
    var reported = 0;
    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'news',
      slot: 'main',
      config: {'minReadMs': 9000},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: NewsSlideWidget(
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
    expect(reported, 9000);
    await db.close();
  });

  testWidgets('article with image loads bytes from blob store', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    final ref = await blobs.putBytes(_tinyPng, logicalKey: 'rss/feed_t/a/img');
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'rss/feed_t/a/img',
            sha256: ref.storageKey,
            relativePath: ref.storageKey,
            bytes: _tinyPng.length,
            mimeType: const Value('image/png'),
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await _insertFeedAndArticle(db, summary: 'Short.', imageBlobKey: 'rss/feed_t/a/img');

    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 8000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'news',
      slot: 'main',
      config: {'minReadMs': 3000},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: NewsSlideWidget(
            db: db,
            blobs: blobs,
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
            onReportDesiredDwell: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);
    await db.close();
  });

  testWidgets('blob read failure hides image panel and uses full-width text', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'rss/feed_t/a/img',
            sha256: 'missing',
            relativePath: 'missing',
            bytes: 4,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await _insertFeedAndArticle(
      db,
      summary: 'Short.',
      imageBlobKey: 'rss/feed_t/a/img',
    );

    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 8000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'news',
      slot: 'main',
      config: {'minReadMs': 3000},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: NewsSlideWidget(
            db: db,
            blobs: FailingReadBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
            onReportDesiredDwell: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rss_article_image_panel')), findsNothing);
    expect(find.byType(Image), findsNothing);
    final textColumn = tester.getRect(
      find.byKey(const Key('rss_article_text_column')),
    );
    expect(textColumn.width, greaterThan(500));
    await db.close();
  });

  testWidgets('selects article with higher image quality for rendering', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();

    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: 'feed_t',
            url: 'http://test.local/feed.xml',
            category: const Value('test'),
          ),
        );

    final lowRef = await blobs.putBytes(_tinyPng, logicalKey: 'rss/low');
    final highRef = await blobs.putBytes(
      List<int>.filled(4096, 1),
      logicalKey: 'rss/high',
    );

    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'rss/low',
            sha256: lowRef.storageKey,
            relativePath: lowRef.storageKey,
            bytes: _tinyPng.length,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'rss/high',
            sha256: highRef.storageKey,
            relativePath: highRef.storageKey,
            bytes: 4096,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await _insertArticle(
      db,
      id: 'a_low',
      title: 'Low quality image',
      publishedAt: 1,
      imageBlobKey: 'rss/low',
    );
    await _insertArticle(
      db,
      id: 'a_high',
      title: 'High quality image',
      publishedAt: 2,
      imageBlobKey: 'rss/high',
    );

    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 8000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'news',
      slot: 'main',
      config: {'minReadMs': 3000},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: NewsSlideWidget(
            db: db,
            blobs: blobs,
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
            onReportDesiredDwell: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('High quality image'), findsOneWidget);
    expect(find.text('Low quality image'), findsNothing);
    await db.close();
  });

  testWidgets('long summary reports extended dwell and scrolls after delay', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = openMemoryDatabase();
    await warmDatabase(db);
    // Newlines guarantee multiple visual lines even when test fonts pack many
    // characters into one soft-wrapped row at typical slide widths.
    final longSummary =
        List.filled(30, 'Line of text for scroll testing.').join('\n');
    await _insertFeedAndArticle(db, summary: longSummary);

    var reported = 0;
    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'news',
      slot: 'main',
      config: {
        'scrollDelayMs': 80,
        'trailingHoldMs': 40,
        'scrollPixelsPerSecond': 800.0,
        'minReadMs': 2000,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: NewsSlideWidget(
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

    final scrollFinder = find.descendant(
      of: find.byKey(const Key('rss_article_summary_scroll')),
      matching: find.byType(Scrollable),
    );
    final scrollState = tester.state<ScrollableState>(scrollFinder);
    final position = scrollState.position;
    expect(position.maxScrollExtent, greaterThan(50));

    final expectedMin = desiredDwellMsForRssArticle(
      baseDwellMs: slide.dwellMs,
      minReadMs: 2000,
      summaryScrollable: true,
      scrollDelayMs: 80,
      trailingHoldMs: 40,
      maxScrollExtent: position.maxScrollExtent,
      scrollPixelsPerSecond: 800,
    );
    expect(reported, expectedMin);

    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, 3.0));

    await db.close();
  });

  testWidgets('shows QR for article link when URL is present', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    const articleUrl = 'https://news.example.com/story/42';
    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: 'feed_t',
            url: 'http://test.local/feed.xml',
            category: const Value('test'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'article_qr',
            feedId: 'feed_t',
            guid: 'gq',
            title: 'Headline',
            link: articleUrl,
            summary: const Value('Body.'),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'news',
      slot: 'main',
      config: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: NewsSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
            onReportDesiredDwell: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rss_article_link_qr')), findsOneWidget);

    await db.close();
  });

  testWidgets('omits QR when article link is empty', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: 'feed_t',
            url: 'http://test.local/feed.xml',
            category: const Value('test'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'article_no_link',
            feedId: 'feed_t',
            guid: 'gnl',
            title: 'Headline',
            link: '',
            summary: const Value('Body.'),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'news',
      slot: 'main',
      config: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: NewsSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
            onReportDesiredDwell: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rss_article_link_qr')), findsNothing);

    await db.close();
  });

  testWidgets('empty title and summary still shows QR when link present', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    const articleUrl = 'https://news.example.com/only-link';
    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: 'feed_t',
            url: 'http://test.local/feed.xml',
            category: const Value('test'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'article_blank',
            feedId: 'feed_t',
            guid: 'gb',
            title: '',
            link: articleUrl,
            summary: const Value.absent(),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'news',
      slot: 'main',
      config: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: NewsSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
            onReportDesiredDwell: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Article has no title or summary'), findsOneWidget);
    expect(find.byKey(const Key('rss_article_link_qr')), findsOneWidget);

    await db.close();
  });
}
