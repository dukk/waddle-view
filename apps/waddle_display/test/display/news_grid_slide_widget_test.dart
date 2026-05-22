import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/news/news_grid_slide_widget.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

Future<void> _insertFeed(AppDatabase db) async {
  await db.into(db.interestsRssFeeds).insert(
        InterestsRssFeedsCompanion.insert(
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
  String summary = 'Summary body text.',
  String link = 'http://test.local/article',
}) async {
  await db.into(db.news).insert(
        NewsCompanion.insert(
          id: id,
          sourceType: kNewsSourceTypeRss,
          sourceId: 'feed_t',
          guid: 'guid_$id',
          title: title,
          link: link,
          summary: Value(summary),
          publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
          fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
}

Map<String, String> _sixChoices() => const {
      'main_news_grid_0': 'a0',
      'main_news_grid_1': 'a1',
      'main_news_grid_2': 'a2',
      'main_news_grid_3': 'a3',
      'main_news_grid_4': 'a4',
      'main_news_grid_5': 'a5',
    };

Future<void> _seedSixArticles(AppDatabase db) async {
  await _insertFeed(db);
  for (var i = 0; i < 6; i++) {
    await _insertArticle(db, id: 'a$i', title: 'Headline $i');
  }
}

Widget _gridHarness({
  required AppDatabase db,
  required ResolvedSlide slide,
  required ParsedWidgetSpec spec,
}) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: SizedBox(
        width: 1200,
        height: 720,
        child: NewsGridSlideWidget(
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
}

void main() {
  testWidgets('shows six headlines without summary by default', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedSixArticles(db);

    final slide = ResolvedSlide(
      screenId: 'news_grid',
      dwellMs: 12000,
      layoutJson: '{}',
      randomChoices: _sixChoices(),
    );
    const spec = ParsedWidgetSpec(
      type: 'news_grid',
      slot: 'main',
      config: {},
    );

    await tester.pumpWidget(_gridHarness(db: db, slide: slide, spec: spec));
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      expect(find.text('Headline $i'), findsOneWidget);
    }
    expect(find.text('Summary body text.'), findsNothing);
    expect(find.byKey(const Key('news_grid_cell_0')), findsOneWidget);
    expect(find.byKey(const Key('news_grid_cell_5')), findsOneWidget);
    await db.close();
  });

  testWidgets('shows summary when showSummary is true', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedSixArticles(db);

    final slide = ResolvedSlide(
      screenId: 'news_grid',
      dwellMs: 12000,
      layoutJson: '{}',
      randomChoices: _sixChoices(),
    );
    const spec = ParsedWidgetSpec(
      type: 'news_grid',
      slot: 'main',
      config: {'showSummary': true},
    );

    await tester.pumpWidget(_gridHarness(db: db, slide: slide, spec: spec));
    await tester.pumpAndSettle();

    expect(find.text('Summary body text.'), findsNWidgets(6));
    await db.close();
  });

  testWidgets('hidden qrMode shows no QR codes', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedSixArticles(db);

    final slide = ResolvedSlide(
      screenId: 'news_grid',
      dwellMs: 12000,
      layoutJson: '{}',
      randomChoices: _sixChoices(),
    );
    const spec = ParsedWidgetSpec(
      type: 'news_grid',
      slot: 'main',
      config: {'qrMode': 'hidden'},
    );

    await tester.pumpWidget(_gridHarness(db: db, slide: slide, spec: spec));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsNothing);
    await db.close();
  });

  testWidgets('image_overlay_left shows QR per linked cell', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedSixArticles(db);

    final slide = ResolvedSlide(
      screenId: 'news_grid',
      dwellMs: 12000,
      layoutJson: '{}',
      randomChoices: _sixChoices(),
    );
    const spec = ParsedWidgetSpec(
      type: 'news_grid',
      slot: 'main',
      config: {'qrMode': 'image_overlay_left'},
    );

    await tester.pumpWidget(_gridHarness(db: db, slide: slide, spec: spec));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsNWidgets(6));
    expect(find.byKey(const ValueKey('news_grid_qr_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('news_grid_qr_5')), findsOneWidget);
    await db.close();
  });

  testWidgets('image_overlay_right shows QR per linked cell', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedSixArticles(db);

    final slide = ResolvedSlide(
      screenId: 'news_grid',
      dwellMs: 12000,
      layoutJson: '{}',
      randomChoices: _sixChoices(),
    );
    const spec = ParsedWidgetSpec(
      type: 'news_grid',
      slot: 'main',
      config: {'qrMode': 'image_overlay_right'},
    );

    await tester.pumpWidget(_gridHarness(db: db, slide: slide, spec: spec));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsNWidgets(6));
    await db.close();
  });
}
