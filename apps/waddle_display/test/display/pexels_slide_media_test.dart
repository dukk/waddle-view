import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/pexels/pexels_slide_media.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  test('loadPhotoBlobBytes returns null when metadata is missing', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'p1',
            mediaBlobKey: 'missing_blob_key',
            photographerName: 'n',
            photographerUrl: 'https://example.com/p',
            pexelsPageUrl: 'https://example.com',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final row = await (db.select(db.photos)..where((t) => t.id.equals('p1')))
        .getSingle();
    final bytes = await loadPhotoBlobBytes(db, FakeBlobStore(), row);
    expect(bytes, isNull);
    await db.close();
  });

  test('loadPhotoBlobBytes returns null when BlobStore.readBytes throws', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'bk1',
            sha256: 'path1',
            relativePath: 'path1',
            bytes: 4,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'p1',
            mediaBlobKey: 'bk1',
            photographerName: 'n',
            photographerUrl: 'https://example.com/p',
            pexelsPageUrl: 'https://example.com',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final row = await (db.select(db.photos)..where((t) => t.id.equals('p1')))
        .getSingle();
    final bytes = await loadPhotoBlobBytes(db, FailingReadBlobStore(), row);
    expect(bytes, isNull);
    await db.close();
  });

  test('loadPhotoBlobBytes returns bytes when blob read succeeds', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    blobs.seed('rel/photo', [10, 20, 30]);
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'bk1',
            sha256: 'abc',
            relativePath: 'rel/photo',
            bytes: 3,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'p1',
            category: const Value('pexels'),
            mediaBlobKey: 'bk1',
            photographerName: 'n',
            photographerUrl: 'https://example.com/p',
            pexelsPageUrl: 'https://example.com',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final row = await (db.select(db.photos)..where((t) => t.id.equals('p1')))
        .getSingle();
    final bytes = await loadPhotoBlobBytes(db, blobs, row);
    expect(bytes, isNotNull);
    expect(bytes!.length, 3);
    expect(bytes[0], 10);
    await db.close();
  });

  test('loadPhotoByCuratedId returns null for null or empty id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    expect(await loadPhotoByCuratedId(db, null), isNull);
    expect(await loadPhotoByCuratedId(db, ''), isNull);
    await db.close();
  });

  test('loadPhotoByCuratedId returns photo when id matches', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'cur_pick',
            mediaBlobKey: 'bk',
            photographerName: 'n',
            photographerUrl: 'https://example.com/p',
            pexelsPageUrl: 'https://example.com',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final row = await loadPhotoByCuratedId(db, 'cur_pick');
    expect(row, isNotNull);
    expect(row!.id, 'cur_pick');
    await db.close();
  });

  test('loadPexelsPhotoForSlide uses curated id from randomChoices', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'curated_photo',
            mediaBlobKey: 'bk',
            photographerName: 'n',
            photographerUrl: 'https://example.com/p',
            pexelsPageUrl: 'https://example.com',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'pexels_photo',
      slot: 'main',
      config: {},
    );
    const slide = ResolvedSlide(
      screenId: 'scr',
      dwellMs: 1000,
      layoutJson: '{}',
      randomChoices: {'main_pexels_photo': 'curated_photo'},
    );
    final photo = await loadPexelsPhotoForSlide(db, spec, slide);
    expect(photo, isNotNull);
    expect(photo!.id, 'curated_photo');
    await db.close();
  });

  test('loadPexelsPhotoForSlide filters by categoryId when no curated id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'cat_a',
            category: const Value('nature'),
            mediaBlobKey: 'bk1',
            photographerName: 'n',
            photographerUrl: 'https://example.com/p',
            pexelsPageUrl: 'https://example.com',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'cat_b',
            category: const Value('urban'),
            mediaBlobKey: 'bk2',
            photographerName: 'n',
            photographerUrl: 'https://example.com/p',
            pexelsPageUrl: 'https://example.com',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'pexels_photo',
      slot: 'hero',
      config: {'categoryId': 'nature'},
    );
    const slide = ResolvedSlide(
      screenId: 'scr',
      dwellMs: 1000,
      layoutJson: '{}',
    );
    final photo = await loadPexelsPhotoForSlide(db, spec, slide);
    expect(photo, isNotNull);
    expect(photo!.id, 'cat_a');
    await db.close();
  });

  test('loadPexelsPhotoForSlide picks suppressed=false without category filter',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'only_photo',
            mediaBlobKey: 'bk',
            photographerName: 'n',
            photographerUrl: 'https://example.com/p',
            pexelsPageUrl: 'https://example.com',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'pexels_photo',
      slot: 'main',
      config: {},
    );
    const slide = ResolvedSlide(
      screenId: 'scr',
      dwellMs: 1000,
      layoutJson: '{}',
    );
    final photo = await loadPexelsPhotoForSlide(db, spec, slide);
    expect(photo, isNotNull);
    expect(photo!.id, 'only_photo');
    await db.close();
  });
}
