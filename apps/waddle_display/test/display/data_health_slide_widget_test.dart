import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/data_health/data_health_slide_widget.dart';
import 'package:waddle_display/theme/display_theme.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  testWidgets('shows charts and blob summary for seeded database', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['general']);

    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'f1',
            url: 'https://example.com/feed.xml',
            category: const Value('general'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a1',
            feedId: 'f1',
            guid: 'g1',
            title: 'Hello',
            link: 'https://x/1',
            summary: const Value('s'),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(2),
            imageBlobKey: const Value('img/a1'),
          ),
        );
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'k1',
            sha256: '0' * 64,
            relativePath: 'a.bin',
            bytes: 200,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(3),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'p1',
            category: const Value('general'),
            mediaBlobKey: 'blob/p1',
            photographerName: 'n',
            photographerUrl: 'https://x/p',
            pexelsPageUrl: 'https://x/photo',
            altText: const Value(''),
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(4),
          ),
        );
    await db.into(db.videos).insert(
          VideosCompanion.insert(
            id: 'v1',
            category: const Value('general'),
            mediaBlobKey: 'blob/v1',
            photographerName: 'n',
            photographerUrl: 'https://x/v',
            pexelsPageUrl: 'https://x/video',
            altText: const Value(''),
            durationSeconds: 5,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(5),
          ),
        );

    const spec = ParsedWidgetSpec(
      type: 'data_health',
      slot: 'main',
      config: {'headline': 'DB stats', 'refreshIntervalSeconds': 120},
    );
    const slide = ResolvedSlide(
      screenId: 'dev_data_health',
      dwellMs: 20000,
      layoutJson:
          '{"v":1,"layout":"single","widgets":[{"type":"data_health","slot":"main","config":{"headline":"DB stats","refreshIntervalSeconds":120}}]}',
    );
    final theme = DisplayTheme.build();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: DataHealthSlideWidget(
            db: db,
            slide: slide,
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DB stats'), findsOneWidget);
    expect(find.textContaining('Updated'), findsOneWidget);
    expect(find.textContaining('200 B'), findsOneWidget);
    expect(find.textContaining('1 on'), findsOneWidget);
    expect(find.text('Active content by type'), findsOneWidget);
    expect(find.text('RSS'), findsWidgets);
    expect(find.text('Photos and videos by category'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows empty placeholders when database has no content', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    final spec = ParsedWidgetSpec(
      type: 'data_health',
      slot: 'main',
      config: {},
    );
    const slide = ResolvedSlide(
      screenId: 'dev_data_health',
      dwellMs: 20000,
      layoutJson:
          '{"v":1,"layout":"single","widgets":[{"type":"data_health","slot":"main","config":{}}]}',
    );
    final theme = DisplayTheme.build();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: DataHealthSlideWidget(
            db: db,
            slide: slide,
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data health'), findsOneWidget);
    expect(find.text('No photos or videos yet.'), findsOneWidget);
    expect(find.text('No RSS articles yet.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows error when database is already closed', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.close();

    final spec = ParsedWidgetSpec(
      type: 'data_health',
      slot: 'main',
      config: {},
    );
    const slide = ResolvedSlide(
      screenId: 'dev_data_health',
      dwellMs: 20000,
      layoutJson:
          '{"v":1,"layout":"single","widgets":[{"type":"data_health","slot":"main","config":{}}]}',
    );
    final theme = DisplayTheme.build();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: DataHealthSlideWidget(
            db: db,
            slide: slide,
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not load database statistics.'),
      findsOneWidget,
    );
  });
}
