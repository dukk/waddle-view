import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/photo_slideshow_media.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_photo_slideshow_settings.dart';

import '../../helpers/memory_database.dart';

Future<void> _insertPhoto(
  AppDatabase db, {
  required String id,
  required String category,
  required String blobKey,
  int? width,
  int? height,
  bool suppressed = false,
}) async {
  await db.into(db.blobMetadata).insert(
        BlobMetadataCompanion.insert(
          blobKey: blobKey,
          sha256: 'sha_$id',
          relativePath: 'rel/$id',
          bytes: 10,
          pixelWidth: width == null ? const Value.absent() : Value(width),
          pixelHeight: height == null ? const Value.absent() : Value(height),
          capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
  await db.into(db.photos).insert(
        PhotosCompanion.insert(
          id: id,
          category: Value(category),
          mediaBlobKey: blobKey,
          photographerName: 'n',
          photographerUrl: 'https://example.com/p',
          pageUrl: 'https://example.com',
          fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          suppressed: Value(suppressed),
        ),
      );
}

void main() {
  test('selectRandomPhotoForSlideshow filters by category', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertPhoto(db, id: 'a', category: 'nature', blobKey: 'bk_a');
    await _insertPhoto(db, id: 'b', category: 'urban', blobKey: 'bk_b');
    const settings = PhotoSlideshowOverlaySettings(
      x: 0,
      y: 0,
      scale: 0.1,
      opacity: 1,
      intervalSec: 60,
      categoryIds: ['nature'],
      aspectRatio: kPhotoSlideshowAspectAny,
    );
    final photo = await selectRandomPhotoForSlideshow(db, settings);
    expect(photo, isNotNull);
    expect(photo!.id, 'a');
    await db.close();
  });

  test('selectRandomPhotoForSlideshow excludes suppressed', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertPhoto(
      db,
      id: 'hidden',
      category: 'nature',
      blobKey: 'bk_h',
      suppressed: true,
    );
    await _insertPhoto(db, id: 'visible', category: 'nature', blobKey: 'bk_v');
    final photo = await selectRandomPhotoForSlideshow(
      db,
      PhotoSlideshowOverlaySettings.defaults,
    );
    expect(photo?.id, 'visible');
    await db.close();
  });

  test('selectRandomPhotoForSlideshow filters landscape aspect', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertPhoto(
      db,
      id: 'wide',
      category: 'nature',
      blobKey: 'bk_w',
      width: 1920,
      height: 1080,
    );
    await _insertPhoto(
      db,
      id: 'tall',
      category: 'nature',
      blobKey: 'bk_t',
      width: 800,
      height: 1200,
    );
    const settings = PhotoSlideshowOverlaySettings(
      x: 0,
      y: 0,
      scale: 0.1,
      opacity: 1,
      intervalSec: 60,
      categoryIds: [],
      aspectRatio: kPhotoSlideshowAspectLandscape,
    );
    final photo = await selectRandomPhotoForSlideshow(db, settings);
    expect(photo?.id, 'wide');
    await db.close();
  });

  test('selectRandomPhotoForSlideshow applies min_width', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertPhoto(
      db,
      id: 'small',
      category: 'nature',
      blobKey: 'bk_s',
      width: 400,
      height: 300,
    );
    await _insertPhoto(
      db,
      id: 'large',
      category: 'nature',
      blobKey: 'bk_l',
      width: 1600,
      height: 900,
    );
    const settings = PhotoSlideshowOverlaySettings(
      x: 0,
      y: 0,
      scale: 0.1,
      opacity: 1,
      intervalSec: 60,
      categoryIds: [],
      aspectRatio: kPhotoSlideshowAspectAny,
      minWidth: 1200,
    );
    final photo = await selectRandomPhotoForSlideshow(db, settings);
    expect(photo?.id, 'large');
    await db.close();
  });

  test('countPhotosForSlideshow returns zero when pool empty', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final count = await countPhotosForSlideshow(
      db,
      const PhotoSlideshowOverlaySettings(
        x: 0,
        y: 0,
        scale: 0.1,
        opacity: 1,
        intervalSec: 60,
        categoryIds: ['missing'],
        aspectRatio: kPhotoSlideshowAspectAny,
      ),
    );
    expect(count, 0);
    await db.close();
  });
}
