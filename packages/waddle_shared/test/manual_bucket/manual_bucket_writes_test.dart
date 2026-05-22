import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/manual_bucket/manual_bucket_writes.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/tables/interests_jokes_seed.dart';
import 'package:waddle_shared/seed/tables/interests_trivia_seed.dart';

import '../helpers/memory_database.dart';

class _MemBlobStore implements BlobStore {
  final Map<String, List<int>> _data = {};

  @override
  Future<void> delete(BlobRef ref) async => _data.remove(ref.storageKey);

  @override
  Future<BlobRef> putBytes(
    List<int> bytes, {
    required String logicalKey,
  }) async {
    final key = 'stored/$logicalKey';
    _data[key] = List<int>.from(bytes);
    return BlobRef(key);
  }

  @override
  Future<List<int>> readBytes(BlobRef ref) async =>
      List<int>.from(_data[ref.storageKey] ?? const []);

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

Uint8List _tinyPng() {
  return Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    ),
  );
}

void main() {
  test('writeManualBucketPhoto stores photo and blob metadata', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['nature']);
    final blobs = _MemBlobStore();
    final bytes = _tinyPng();

    final result = await writeManualBucketPhoto(
      db: db,
      blobs: blobs,
      category: 'nature',
      bytes: bytes,
      contentType: 'image/png',
      altText: 'sunset',
      photographerName: 'Operator',
    );

    final photo = await (db.select(
      db.photos,
    )..where((t) => t.id.equals(result.id))).getSingle();
    expect(photo.category, 'nature');
    expect(photo.dataProvider, kManualEntrySource);
    expect(photo.mediaBlobKey, result.mediaBlobKey);
    expect(photo.altText, 'sunset');

    final meta = await (db.select(
      db.blobMetadata,
    )..where((t) => t.blobKey.equals(result.mediaBlobKey!))).getSingle();
    expect(meta.mimeType, 'image/png');
    expect(meta.bytes, bytes.length);
  });

  test('writeManualBucketPhoto rejects unknown category', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await expectLater(
      writeManualBucketPhoto(
        db: db,
        blobs: _MemBlobStore(),
        category: 'missing',
        bytes: _tinyPng(),
        contentType: 'image/png',
      ),
      throwsA(
        isA<ManualBucketWriteException>().having(
          (e) => e.code,
          'code',
          'unknown_category',
        ),
      ),
    );
  });

  test('writeManualBucketJoke stores joke row', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultInterestsJokes(db);

    final result = await writeManualBucketJoke(
      db: db,
      categoryId: 'dad',
      setup: 'Why did the chicken cross the road?',
      punchline: 'To get to the other side.',
    );

    final row = await (db.select(
      db.jokes,
    )..where((t) => t.id.equals(result.id))).getSingle();
    expect(row.categoryId, 'dad');
    expect(row.setup, contains('chicken'));
  });

  test(
    'writeManualBucketTrivia stores question without integration id',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      await ensureDefaultInterestsTrivia(db);

      final result = await writeManualBucketTrivia(
        db: db,
        categoryId: 'science',
        question: 'What is 2+2?',
        optionA: '3',
        optionB: '4',
        optionC: '5',
        optionD: '6',
        correctOption: 'B',
      );

      final row = await (db.select(
        db.triviaQuestions,
      )..where((t) => t.id.equals(result.id))).getSingle();
      expect(row.integrationId, isNull);
      expect(row.correctOption, 'B');
    },
  );

  test('writeManualBucketCalendarEvent stores event and categories', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['family']);

    final start = DateTime.utc(2026, 6, 1, 14);
    final end = DateTime.utc(2026, 6, 1, 15);
    final result = await writeManualBucketCalendarEvent(
      db: db,
      title: 'Team lunch',
      startMs: start,
      endMs: end,
      allDay: false,
      categoryIds: ['family'],
      location: 'Cafe',
    );

    final event = await (db.select(
      db.calendarEvents,
    )..where((t) => t.id.equals(result.id))).getSingle();
    expect(event.title, 'Team lunch');
    expect(event.source, kManualEntrySource);
    expect(event.categoryId, 'family');

    final junction = await (db.select(
      db.calendarEventCategories,
    )..where((t) => t.eventId.equals(result.id))).get();
    expect(junction, hasLength(1));
    expect(junction.single.categoryId, 'family');
  });

  test('writeManualBucketQuote stores quote and categories', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['wisdom']);

    final result = await writeManualBucketQuote(
      db: db,
      text: 'To be or not to be.',
      authorName: 'Shakespeare',
      categoryIds: ['wisdom'],
    );

    expect(result.id, startsWith('bucket_quote_'));
    final row = await (db.select(db.quoterismQuotes)
          ..where((t) => t.id.equals(result.id)))
        .getSingle();
    expect(row.quoteText, 'To be or not to be.');
    expect(row.authorName, 'Shakespeare');
    expect(row.integrationId, isNull);

    final junction = await (db.select(db.quoterismQuoteCategories)
          ..where((t) => t.quoteId.equals(result.id)))
        .get();
    expect(junction, hasLength(1));
    expect(junction.single.categoryId, 'wisdom');
  });
}
