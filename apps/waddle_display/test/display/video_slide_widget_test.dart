import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/photo/photo_attribution_overlay.dart';
import 'package:waddle_display/display/screens/photo/video_slide_widget.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

VideosCompanion _vid(String id, String category, String blobKey) =>
    VideosCompanion.insert(
      id: id,
      category: Value(category),
      mediaBlobKey: blobKey,
      photographerName: 'P',
      photographerUrl: 'https://www.pexels.com/@p',
      pexelsPageUrl: 'https://www.pexels.com/video/$id/',
      altText: const Value(''),
      durationSeconds: 10,
      fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadPexelsVideoForSlide uses curated id from randomChoices', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await db.into(db.videos).insert(_vid('a', 'c1', 'b1'));
    await db.into(db.videos).insert(_vid('b', 'c1', 'b2'));
    const spec = ParsedWidgetSpec(type: 'video', slot: 'main', config: {});
    final slide = ResolvedSlide(
      screenId: 's',
      dwellMs: 1,
      layoutJson: '',
      randomChoices: const {'main_video': 'b'},
    );
    final row = await loadPexelsVideoForSlide(db, spec, slide);
    expect(row?.id, 'b');
  });

  test('loadPexelsVideoForSlide filters by categoryId in config', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await db.into(db.videos).insert(_vid('x', 'nature', 'bx'));
    await db.into(db.videos).insert(_vid('y', 'urban', 'by'));
    const spec = ParsedWidgetSpec(
      type: 'video',
      slot: 'main',
      config: {'categoryId': 'urban'},
    );
    final slide = ResolvedSlide(
      screenId: 's',
      dwellMs: 1,
      layoutJson: '',
      randomChoices: const {},
    );
    final row = await loadPexelsVideoForSlide(db, spec, slide);
    expect(row?.id, 'y');
  });

  testWidgets('shows placeholder when no videos in database', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    const layout = ParsedWidgetSpec(type: 'video', slot: 'main', config: {});
    final slide = ResolvedSlide(
      screenId: 's',
      dwellMs: 5000,
      layoutJson: '',
      randomChoices: const {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: VideoSlideWidget(
            db: db,
            blobs: blobs,
            slide: slide,
            spec: layout,
            theme: ThemeData.dark(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No Pexels video'), findsOneWidget);
    await db.close();
  });

  testWidgets('shows error when blob metadata missing for video row', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    await db
        .into(db.videos)
        .insert(
          VideosCompanion.insert(
            id: 'vx',
            category: const Value('pexels'),
            mediaBlobKey: 'missing-meta-key',
            photographerName: 'P',
            photographerUrl: 'https://www.pexels.com/@p',
            pexelsPageUrl: 'https://www.pexels.com/video/1/',
            altText: const Value(''),
            durationSeconds: 12,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    const layout = ParsedWidgetSpec(
      type: 'video',
      slot: 'main',
      config: {'unmuted': '1', 'loop': '0'},
    );
    final slide = ResolvedSlide(
      screenId: 's',
      dwellMs: 5000,
      layoutJson: '',
      randomChoices: const {'main_video': 'vx'},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: VideoSlideWidget(
            db: db,
            blobs: blobs,
            slide: slide,
            spec: layout,
            theme: ThemeData.dark(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('missing blob metadata'), findsOneWidget);
    await db.close();
  });

  testWidgets('defer playback surface when allowPlayback is false', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    final ref = await blobs.putBytes([1, 2, 3], logicalKey: 'vid/ok');
    await db
        .into(db.blobMetadata)
        .insert(
          BlobMetadataCompanion.insert(
            blobKey: 'vid/ok',
            sha256: 'abc',
            relativePath: ref.storageKey,
            bytes: 3,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db
        .into(db.videos)
        .insert(
          VideosCompanion.insert(
            id: 'vok',
            category: const Value('pexels'),
            mediaBlobKey: 'vid/ok',
            photographerName: 'P',
            photographerUrl: 'https://www.pexels.com/@p',
            pexelsPageUrl: 'https://www.pexels.com/video/3/',
            altText: const Value(''),
            durationSeconds: 12,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    const layout = ParsedWidgetSpec(type: 'video', slot: 'main', config: {});
    final slide = ResolvedSlide(
      screenId: 's',
      dwellMs: 5000,
      layoutJson: '',
      randomChoices: const {'main_video': 'vok'},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: VideoSlideWidget(
            db: db,
            blobs: blobs,
            slide: slide,
            spec: layout,
            theme: ThemeData.dark(),
            allowPlayback: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('pexels_video_surface')), findsNothing);
    await db.close();
  });

  testWidgets('shows error when video bytes are empty', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    final ref = await blobs.putBytes([], logicalKey: 'vid/empty');
    await db
        .into(db.blobMetadata)
        .insert(
          BlobMetadataCompanion.insert(
            blobKey: 'vid/empty',
            sha256: 'e',
            relativePath: ref.storageKey,
            bytes: 0,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db
        .into(db.videos)
        .insert(
          VideosCompanion.insert(
            id: 've',
            category: const Value('pexels'),
            mediaBlobKey: 'vid/empty',
            photographerName: 'P',
            photographerUrl: 'https://www.pexels.com/@p',
            pexelsPageUrl: 'https://www.pexels.com/video/2/',
            altText: const Value(''),
            durationSeconds: 12,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    const layout = ParsedWidgetSpec(
      type: 'video',
      slot: 'main',
      config: {'unmuted': false, 'loop': true},
    );
    final slide = ResolvedSlide(
      screenId: 's',
      dwellMs: 5000,
      layoutJson: '',
      randomChoices: const {'main_video': 've'},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: VideoSlideWidget(
            db: db,
            blobs: blobs,
            slide: slide,
            spec: layout,
            theme: ThemeData.dark(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('empty video bytes'), findsOneWidget);
    await db.close();
  });

  testWidgets('hides photographer attribution when overlay config is off', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    final ref = await blobs.putBytes([1, 2, 3], logicalKey: 'vid/attr-off');
    await db
        .into(db.blobMetadata)
        .insert(
          BlobMetadataCompanion.insert(
            blobKey: 'vid/attr-off',
            sha256: 'abc',
            relativePath: ref.storageKey,
            bytes: 3,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db
        .into(db.videos)
        .insert(
          VideosCompanion.insert(
            id: 'voff',
            category: const Value('pexels'),
            mediaBlobKey: 'vid/attr-off',
            photographerName: 'Pat Video',
            photographerUrl: 'https://www.pexels.com/@pat',
            pexelsPageUrl: 'https://www.pexels.com/video/voff/',
            altText: const Value('Clip'),
            durationSeconds: 12,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    const layout = ParsedWidgetSpec(type: 'video', slot: 'main', config: {});
    final slide = ResolvedSlide(
      screenId: 's',
      dwellMs: 5000,
      layoutJson: '',
      randomChoices: const {'main_video': 'voff'},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: VideoSlideWidget(
            db: db,
            blobs: blobs,
            slide: slide,
            spec: layout,
            theme: ThemeData.dark(),
            allowPlayback: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(PexelsAttributionOverlay), findsNothing);
    await db.close();
  });
}
