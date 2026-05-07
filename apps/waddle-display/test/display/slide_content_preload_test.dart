import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/slide_content_preload.dart';
import 'package:waddle_display/persistence/database.dart';
import 'package:waddle_display/seed/tables/content_categories_seed.dart';
import 'package:waddle_display/seed/tables/joke_categories_seed.dart';
import 'package:waddle_display/seed/tables/trivia_categories_seed.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  test('preloadResolvedSlideContent completes for joke layout', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    await ensureDefaultContentCategories(db);
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 't_preload_joke',
            categoryId: 'dad',
            setup: 'S',
            punchline: 'P',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'jokes',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"joke","slot":"main","config":{}}]}',
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });

  test('preloadResolvedSlideContent completes for trivia layout', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultTriviaCategories(db);
    await ensureDefaultContentCategories(db);
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 't_preload_trivia',
            categoryId: 'science',
            question: 'Q?',
            optionA: 'a',
            optionB: 'b',
            optionC: 'c',
            optionD: 'd',
            correctOption: 'A',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'trivia',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"trivia","slot":"main","config":{}}]}',
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });

  test('preloadResolvedSlideContent warms pexels_photo blob bytes', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    blobs.seed('rel/photo1', [1, 2, 3, 4]);
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'bk_preload_photo',
            sha256: 'abc',
            relativePath: 'rel/photo1',
            bytes: 4,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'photo_preload_1',
            mediaBlobKey: 'bk_preload_photo',
            photographerName: 'n',
            photographerUrl: 'https://example.com/p',
            pexelsPageUrl: 'https://example.com',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'pex',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"pexels_photo","slot":"a","config":{}}]}',
      randomChoices: {'a_pexels_photo': 'photo_preload_1'},
    );
    await preloadResolvedSlideContent(db: db, blobs: blobs, slide: slide);
    await db.close();
  });

  test('preloadResolvedSlideContent no-ops for empty widgets', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final slide = ResolvedSlide(
      screenId: 'empty',
      dwellMs: 1000,
      layoutJson: '{"widgets":[]}',
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });
}
