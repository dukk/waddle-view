import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../blob/blob_store.dart';
import '../curation/reject_filter_context.dart';
import '../persistence/calendar_event_categories.dart';
import '../persistence/calendar_event_upsert.dart';
import '../persistence/database.dart';
import '../persistence/tables.dart';

/// Validation or persistence failure for manual bucket writes.
class ManualBucketWriteException implements Exception {
  ManualBucketWriteException(this.code, [this.detail]);

  final String code;
  final String? detail;

  @override
  String toString() => detail == null ? code : '$code: $detail';
}

class ManualBucketWriteResult {
  const ManualBucketWriteResult({required this.id, this.mediaBlobKey});

  final String id;
  final String? mediaBlobKey;
}

const int kManualBucketPhotoMaxBytes = 8 * 1024 * 1024;
const int kManualBucketVideoMaxBytes = 50 * 1024 * 1024;

const Set<String> kManualBucketPhotoMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
};

const Set<String> kManualBucketVideoMimeTypes = {
  'video/mp4',
  'video/webm',
  'video/quicktime',
};

String newManualBucketId(String kind) {
  final r = Random.secure();
  final hex = List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  return 'bucket_${kind}_$hex';
}

List<int> decodeManualBucketBytes(String bytesBase64) {
  final trimmed = bytesBase64.trim();
  if (trimmed.isEmpty) {
    throw ManualBucketWriteException('bytes_base64_required');
  }
  try {
    return base64Decode(trimmed);
  } on Object {
    throw ManualBucketWriteException('invalid_base64');
  }
}

String normalizeManualBucketMime(String? raw, Set<String> allowed) {
  var mime = 'image/jpeg';
  if (raw != null && raw.trim().isNotEmpty) {
    mime = raw.split(';').first.trim().toLowerCase();
  }
  if (!allowed.contains(mime)) {
    throw ManualBucketWriteException('unsupported_content_type', mime);
  }
  return mime;
}

Future<void> _assertContentCategoryExists(AppDatabase db, String categoryId) async {
  final id = categoryId.trim();
  if (id.isEmpty) {
    throw ManualBucketWriteException('category_required');
  }
  final row = await (db.select(db.contentCategories)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  if (row == null) {
    throw ManualBucketWriteException('unknown_category', id);
  }
}

Future<void> _assertJokeCategoryExists(AppDatabase db, String categoryId) async {
  final id = categoryId.trim();
  if (id.isEmpty) {
    throw ManualBucketWriteException('category_id_required');
  }
  final row = await (db.select(db.interestsJokes)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  if (row == null) {
    throw ManualBucketWriteException('unknown_joke_category', id);
  }
}

Future<void> _assertTriviaCategoryExists(AppDatabase db, String categoryId) async {
  final id = categoryId.trim();
  if (id.isEmpty) {
    throw ManualBucketWriteException('category_id_required');
  }
  final row = await (db.select(db.interestsTrivia)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  if (row == null) {
    throw ManualBucketWriteException('unknown_trivia_category', id);
  }
}

Future<ManualBucketWriteResult> writeManualBucketPhoto({
  required AppDatabase db,
  required BlobStore blobs,
  required String category,
  required List<int> bytes,
  required String contentType,
  String? altText,
  String? photographerName,
  RejectFilterContext? rejectCtx,
}) async {
  if (bytes.isEmpty) {
    throw ManualBucketWriteException('empty_image');
  }
  if (bytes.length > kManualBucketPhotoMaxBytes) {
    throw ManualBucketWriteException('image_too_large');
  }
  final cat = category.trim();
  await _assertContentCategoryExists(db, cat);
  final mime = normalizeManualBucketMime(contentType, kManualBucketPhotoMimeTypes);
  final filter = rejectCtx ?? await RejectFilterContext.loadFromDb(db);
  final photographer = (photographerName ?? '').trim();
  final alt = (altText ?? '').trim();
  final now = DateTime.now();
  final id = newManualBucketId('photo');
  final logicalKey = 'bucket/photo/$id/image';
  final ref = await blobs.putBytes(bytes, logicalKey: logicalKey);
  await db.into(db.blobMetadata).insertOnConflictUpdate(
        BlobMetadataCompanion.insert(
          blobKey: logicalKey,
          sha256: ref.storageKey.split('/').last,
          relativePath: ref.storageKey,
          bytes: bytes.length,
          mimeType: Value(mime),
          capturedAt: now,
        ),
      );
  final blocked = filter.isMediaRejected(
    photographer: photographer,
    altText: alt,
    urls: const [],
  );
  await db.into(db.photos).insert(
        PhotosCompanion.insert(
          id: id,
          category: Value(cat),
          dataProvider: const Value(kManualEntrySource),
          mediaBlobKey: logicalKey,
          photographerName: photographer,
          photographerUrl: '',
          pageUrl: '',
          altText: Value(alt),
          fetchedAtMs: now,
          suppressed: Value(blocked),
        ),
      );
  return ManualBucketWriteResult(id: id, mediaBlobKey: logicalKey);
}

Future<ManualBucketWriteResult> writeManualBucketVideo({
  required AppDatabase db,
  required BlobStore blobs,
  required String category,
  required List<int> bytes,
  required String contentType,
  required int durationSeconds,
  String? altText,
  String? photographerName,
  RejectFilterContext? rejectCtx,
}) async {
  if (bytes.isEmpty) {
    throw ManualBucketWriteException('empty_video');
  }
  if (bytes.length > kManualBucketVideoMaxBytes) {
    throw ManualBucketWriteException('video_too_large');
  }
  if (durationSeconds < 1) {
    throw ManualBucketWriteException('duration_seconds_required');
  }
  final cat = category.trim();
  await _assertContentCategoryExists(db, cat);
  final mime = normalizeManualBucketMime(contentType, kManualBucketVideoMimeTypes);
  final filter = rejectCtx ?? await RejectFilterContext.loadFromDb(db);
  final photographer = (photographerName ?? '').trim();
  final alt = (altText ?? '').trim();
  final now = DateTime.now();
  final id = newManualBucketId('video');
  final logicalKey = 'bucket/video/$id/media';
  final ref = await blobs.putBytes(bytes, logicalKey: logicalKey);
  await db.into(db.blobMetadata).insertOnConflictUpdate(
        BlobMetadataCompanion.insert(
          blobKey: logicalKey,
          sha256: ref.storageKey.split('/').last,
          relativePath: ref.storageKey,
          bytes: bytes.length,
          mimeType: Value(mime),
          capturedAt: now,
        ),
      );
  final blocked = filter.isMediaRejected(
    photographer: photographer,
    altText: alt,
    urls: const [],
  );
  await db.into(db.videos).insert(
        VideosCompanion.insert(
          id: id,
          category: Value(cat),
          dataProvider: const Value(kManualEntrySource),
          mediaBlobKey: logicalKey,
          photographerName: photographer,
          photographerUrl: '',
          pexelsPageUrl: '',
          altText: Value(alt),
          durationSeconds: durationSeconds,
          fetchedAtMs: now,
          suppressed: Value(blocked),
        ),
      );
  return ManualBucketWriteResult(id: id, mediaBlobKey: logicalKey);
}

Future<ManualBucketWriteResult> writeManualBucketJoke({
  required AppDatabase db,
  required String categoryId,
  required String setup,
  required String punchline,
  RejectFilterContext? rejectCtx,
}) async {
  final cid = categoryId.trim();
  await _assertJokeCategoryExists(db, cid);
  final s = setup.trim();
  final p = punchline.trim();
  if (s.isEmpty || p.isEmpty) {
    throw ManualBucketWriteException('setup_and_punchline_required');
  }
  final filter = rejectCtx ?? await RejectFilterContext.loadFromDb(db);
  final blocked = filter.isBlockedAny([s, p]);
  final id = newManualBucketId('joke');
  final now = DateTime.now();
  await db.into(db.jokes).insert(
        JokesCompanion.insert(
          id: id,
          categoryId: cid,
          setup: s,
          punchline: p,
          createdAtMs: now,
          suppressed: Value(blocked),
        ),
      );
  return ManualBucketWriteResult(id: id);
}

Future<ManualBucketWriteResult> writeManualBucketTrivia({
  required AppDatabase db,
  required String categoryId,
  required String question,
  required String optionA,
  required String optionB,
  required String optionC,
  required String optionD,
  required String correctOption,
  RejectFilterContext? rejectCtx,
}) async {
  final cid = categoryId.trim();
  await _assertTriviaCategoryExists(db, cid);
  final qt = question.trim();
  final a = optionA.trim();
  final b = optionB.trim();
  final c = optionC.trim();
  final d = optionD.trim();
  if (qt.isEmpty || a.isEmpty || b.isEmpty || c.isEmpty || d.isEmpty) {
    throw ManualBucketWriteException('trivia_fields_required');
  }
  final correct = correctOption.trim().toUpperCase();
  if (!{'A', 'B', 'C', 'D'}.contains(correct)) {
    throw ManualBucketWriteException('invalid_correct_option');
  }
  final filter = rejectCtx ?? await RejectFilterContext.loadFromDb(db);
  final blocked = filter.isBlockedAny([qt, a, b, c, d]);
  final id = newManualBucketId('trivia');
  final now = DateTime.now();
  await db.into(db.triviaQuestions).insert(
        TriviaQuestionsCompanion.insert(
          id: id,
          categoryId: cid,
          question: qt,
          optionA: a,
          optionB: b,
          optionC: c,
          optionD: d,
          correctOption: correct,
          createdAtMs: now,
          integrationId: const Value.absent(),
          suppressed: Value(blocked),
        ),
      );
  return ManualBucketWriteResult(id: id);
}

Future<ManualBucketWriteResult> writeManualBucketCalendarEvent({
  required AppDatabase db,
  required String title,
  required DateTime startMs,
  required DateTime endMs,
  required bool allDay,
  required List<String> categoryIds,
  String? location,
  String? description,
}) async {
  final t = title.trim();
  if (t.isEmpty) {
    throw ManualBucketWriteException('title_required');
  }
  final normalizedCats = normalizeCalendarEventCategoryIds(categoryIds);
  for (final cat in normalizedCats) {
    await _assertContentCategoryExists(db, cat);
  }
  if (endMs.isBefore(startMs)) {
    throw ManualBucketWriteException('end_before_start');
  }
  final id = newManualBucketId('cal');
  final now = DateTime.now();
  await upsertCalendarEventWithCategories(
    db,
    companion: CalendarEventsCompanion.insert(
      id: id,
      title: t,
      startMs: startMs,
      endMs: endMs,
      allDay: Value(allDay),
      location: location == null || location.trim().isEmpty
          ? const Value.absent()
          : Value(location.trim()),
      description: description == null || description.trim().isEmpty
          ? const Value.absent()
          : Value(description.trim()),
      source: const Value(kManualEntrySource),
      updatedAtMs: now,
    ),
    categoryIds: normalizedCats,
  );
  return ManualBucketWriteResult(id: id);
}
