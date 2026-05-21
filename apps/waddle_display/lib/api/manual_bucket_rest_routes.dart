import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/manual_bucket/manual_bucket_writes.dart';
import 'package:waddle_shared/persistence/database.dart';

void registerManualBucketRestRoutes(
  Router r, {
  required AppDatabase db,
  required BlobStore blobs,
}) {
  r.post(
    '/v1/curator/manual/photos',
    (Request req) => _postPhoto(req, db: db, blobs: blobs),
  );

  r.post(
    '/v1/curator/manual/videos',
    (Request req) => _postVideo(req, db: db, blobs: blobs),
  );

  r.post(
    '/v1/curator/manual/jokes',
    (Request req) => _postJoke(req, db: db),
  );

  r.post(
    '/v1/curator/manual/trivia',
    (Request req) => _postTrivia(req, db: db),
  );

  r.post(
    '/v1/curator/manual/calendar-events',
    (Request req) => _postCalendarEvent(req, db: db),
  );
}

Future<Map<String, dynamic>?> _parseBody(Request req) async {
  try {
    final decoded = jsonDecode(await req.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  } catch (_) {
    return null;
  }
}

Response _jsonError(int status, String code, [String? detail]) {
  final body = <String, String>{'error': code};
  if (detail != null && detail.isNotEmpty) {
    body['detail'] = detail;
  }
  return Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json'},
  );
}

Response _jsonCreated(Map<String, Object?> body) {
  return Response(
    201,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json'},
  );
}

Response _mapManualBucketError(ManualBucketWriteException e) {
  return _jsonError(400, e.code, e.detail);
}

Future<Response> _postPhoto(
  Request req, {
  required AppDatabase db,
  required BlobStore blobs,
}) async {
  final map = await _parseBody(req);
  if (map == null) {
    return _jsonError(400, 'invalid_json');
  }
  try {
    final bytes = decodeManualBucketBytes('${map['bytes_base64'] ?? ''}');
    final result = await writeManualBucketPhoto(
      db: db,
      blobs: blobs,
      category: '${map['category'] ?? ''}',
      bytes: bytes,
      contentType: '${map['content_type'] ?? ''}',
      altText: map['alt_text'] as String?,
      photographerName: map['photographer_name'] as String?,
    );
    return _jsonCreated({
      'id': result.id,
      if (result.mediaBlobKey != null) 'blob_key': result.mediaBlobKey!,
    });
  } on ManualBucketWriteException catch (e) {
    return _mapManualBucketError(e);
  }
}

Future<Response> _postVideo(
  Request req, {
  required AppDatabase db,
  required BlobStore blobs,
}) async {
  final map = await _parseBody(req);
  if (map == null) {
    return _jsonError(400, 'invalid_json');
  }
  try {
    final duration = map['duration_seconds'];
    final durationSeconds = duration is int
        ? duration
        : duration is num
            ? duration.toInt()
            : int.tryParse('$duration') ?? 0;
    final bytes = decodeManualBucketBytes('${map['bytes_base64'] ?? ''}');
    final result = await writeManualBucketVideo(
      db: db,
      blobs: blobs,
      category: '${map['category'] ?? ''}',
      bytes: bytes,
      contentType: '${map['content_type'] ?? ''}',
      durationSeconds: durationSeconds,
      altText: map['alt_text'] as String?,
      photographerName: map['photographer_name'] as String?,
    );
    return _jsonCreated({
      'id': result.id,
      if (result.mediaBlobKey != null) 'blob_key': result.mediaBlobKey!,
    });
  } on ManualBucketWriteException catch (e) {
    return _mapManualBucketError(e);
  }
}

Future<Response> _postJoke(
  Request req, {
  required AppDatabase db,
}) async {
  final map = await _parseBody(req);
  if (map == null) {
    return _jsonError(400, 'invalid_json');
  }
  try {
    final result = await writeManualBucketJoke(
      db: db,
      categoryId: '${map['category_id'] ?? ''}',
      setup: '${map['setup'] ?? ''}',
      punchline: '${map['punchline'] ?? ''}',
    );
    return _jsonCreated({'id': result.id});
  } on ManualBucketWriteException catch (e) {
    return _mapManualBucketError(e);
  }
}

Future<Response> _postTrivia(
  Request req, {
  required AppDatabase db,
}) async {
  final map = await _parseBody(req);
  if (map == null) {
    return _jsonError(400, 'invalid_json');
  }
  try {
    final result = await writeManualBucketTrivia(
      db: db,
      categoryId: '${map['category_id'] ?? ''}',
      question: '${map['question'] ?? ''}',
      optionA: '${map['option_a'] ?? ''}',
      optionB: '${map['option_b'] ?? ''}',
      optionC: '${map['option_c'] ?? ''}',
      optionD: '${map['option_d'] ?? ''}',
      correctOption: '${map['correct_option'] ?? ''}',
    );
    return _jsonCreated({'id': result.id});
  } on ManualBucketWriteException catch (e) {
    return _mapManualBucketError(e);
  }
}

Future<Response> _postCalendarEvent(
  Request req, {
  required AppDatabase db,
}) async {
  final map = await _parseBody(req);
  if (map == null) {
    return _jsonError(400, 'invalid_json');
  }
  try {
    final start = _parseDateTimeMs(map['start_ms']);
    final end = _parseDateTimeMs(map['end_ms']);
    if (start == null || end == null) {
      throw ManualBucketWriteException('start_ms_and_end_ms_required');
    }
    final allDay = map['all_day'] == true;
    final categoryIds = _parseCategoryIds(map);
    final result = await writeManualBucketCalendarEvent(
      db: db,
      title: '${map['title'] ?? ''}',
      startMs: start,
      endMs: end,
      allDay: allDay,
      categoryIds: categoryIds,
      location: map['location'] as String?,
      description: map['description'] as String?,
    );
    return _jsonCreated({'id': result.id});
  } on ManualBucketWriteException catch (e) {
    return _mapManualBucketError(e);
  }
}

DateTime? _parseDateTimeMs(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
  }
  if (raw is String && raw.trim().isNotEmpty) {
    final asInt = int.tryParse(raw.trim());
    if (asInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
    }
    return DateTime.tryParse(raw.trim())?.toUtc();
  }
  return null;
}

List<String> _parseCategoryIds(Map<String, dynamic> map) {
  final rawIds = map['category_ids'];
  if (rawIds is List) {
    return rawIds.map((e) => '$e').toList();
  }
  final single = map['category_id'];
  if (single != null && '$single'.trim().isNotEmpty) {
    return ['$single'];
  }
  return const [];
}
