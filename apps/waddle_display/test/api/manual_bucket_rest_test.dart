import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/seed/initial_seed.dart';
import 'package:waddle_shared/seed/tables/interests_jokes_seed.dart';
import 'package:waddle_shared/seed/tables/interests_trivia_seed.dart';

import '../helpers/memory_database.dart';
import '../helpers/rest_auth_helper.dart';

const _tinyPngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  test('POST curator manual photo creates catalog row', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final harness = await RestTestHarness.start(database: db);
    try {
      final res = await http.post(
        Uri.parse('${harness.baseUrl}/v1/curator/manual/photos'),
        headers: harness.authHeaders,
        body: jsonEncode({
          'category': 'pexels',
          'bytes_base64': _tinyPngB64,
          'content_type': 'image/png',
          'alt_text': 'manual upload',
        }),
      );
      expect(res.statusCode, 201, reason: res.body);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final id = body['id'] as String;
      expect(id, startsWith('bucket_photo_'));

      final photo = await (db.select(db.photos)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(photo.dataProvider, kManualEntrySource);
      expect(photo.category, 'pexels');
    } finally {
      await harness.dispose();
    }
  });

  test('POST curator manual joke requires curator.write role', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    await ensureDefaultInterestsJokes(db);
    final harness = await RestTestHarness.start(
      database: db,
      role: kUserRoleViewer,
    );
    try {
      final res = await http.post(
        Uri.parse('${harness.baseUrl}/v1/curator/manual/jokes'),
        headers: harness.authHeaders,
        body: jsonEncode({
          'category_id': 'dad',
          'setup': 'Test setup',
          'punchline': 'Test punchline',
        }),
      );
      expect(res.statusCode, 403);
    } finally {
      await harness.dispose();
    }
  });

  test('POST curator manual quoterism quote creates catalog row', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final harness = await RestTestHarness.start(database: db);
    try {
      final res = await http.post(
        Uri.parse('${harness.baseUrl}/v1/curator/manual/quoterism-quotes'),
        headers: harness.authHeaders,
        body: jsonEncode({
          'text': 'Stay hungry, stay foolish.',
          'author_name': 'Steve Jobs',
          'category_ids': ['general'],
        }),
      );
      expect(res.statusCode, 201, reason: res.body);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final id = body['id'] as String;
      expect(id, startsWith('bucket_quote_'));

      final quote = await (db.select(db.quoterismQuotes)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(quote.quoteText, contains('hungry'));
    } finally {
      await harness.dispose();
    }
  });

  test('POST curator manual video creates catalog row', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final harness = await RestTestHarness.start(database: db);
    try {
      final res = await http.post(
        Uri.parse('${harness.baseUrl}/v1/curator/manual/videos'),
        headers: harness.authHeaders,
        body: jsonEncode({
          'category': 'pexels',
          'bytes_base64': _tinyPngB64,
          'content_type': 'video/mp4',
          'duration_seconds': 5,
          'alt_text': 'clip',
        }),
      );
      expect(res.statusCode, 201, reason: res.body);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['id'], startsWith('bucket_video_'));
    } finally {
      await harness.dispose();
    }
  });

  test('POST curator manual joke succeeds for curator role', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    await ensureDefaultInterestsJokes(db);
    final harness = await RestTestHarness.start(database: db);
    try {
      final res = await http.post(
        Uri.parse('${harness.baseUrl}/v1/curator/manual/jokes'),
        headers: harness.authHeaders,
        body: jsonEncode({
          'category_id': 'dad',
          'setup': 'Why?',
          'punchline': 'Because.',
        }),
      );
      expect(res.statusCode, 201, reason: res.body);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['id'], startsWith('bucket_joke_'));
    } finally {
      await harness.dispose();
    }
  });

  test('POST curator manual trivia creates question row', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    await ensureDefaultInterestsTrivia(db);
    final harness = await RestTestHarness.start(database: db);
    try {
      final res = await http.post(
        Uri.parse('${harness.baseUrl}/v1/curator/manual/trivia'),
        headers: harness.authHeaders,
        body: jsonEncode({
          'category_id': 'science',
          'question': '2+2?',
          'option_a': '3',
          'option_b': '4',
          'option_c': '5',
          'option_d': '6',
          'correct_option': 'B',
        }),
      );
      expect(res.statusCode, 201, reason: res.body);
    } finally {
      await harness.dispose();
    }
  });

  test('POST curator manual calendar event creates row', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final harness = await RestTestHarness.start(database: db);
    try {
      final res = await http.post(
        Uri.parse('${harness.baseUrl}/v1/curator/manual/calendar-events'),
        headers: harness.authHeaders,
        body: jsonEncode({
          'title': 'Standup',
          'start_ms': 1,
          'end_ms': 3600001,
          'all_day': false,
          'category_ids': ['general'],
          'location': 'Room A',
        }),
      );
      expect(res.statusCode, 201, reason: res.body);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['id'], startsWith('bucket_cal_'));
    } finally {
      await harness.dispose();
    }
  });

  test('POST curator manual endpoints reject invalid json', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final harness = await RestTestHarness.start(database: db);
    try {
      final res = await http.post(
        Uri.parse('${harness.baseUrl}/v1/curator/manual/photos'),
        headers: harness.authHeaders,
        body: 'not-json',
      );
      expect(res.statusCode, 400);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['error'], 'invalid_json');
    } finally {
      await harness.dispose();
    }
  });

  test('legacy integration bucket routes are not registered', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final harness = await RestTestHarness.start(database: db);
    try {
      final res = await http.post(
        Uri.parse(
          '${harness.baseUrl}/v1/integrations/default_photo_bucket/bucket/photos',
        ),
        headers: harness.authHeaders,
        body: jsonEncode({
          'category': 'pexels',
          'bytes_base64': _tinyPngB64,
          'content_type': 'image/png',
        }),
      );
      expect(res.statusCode, 404);
    } finally {
      await harness.dispose();
    }
  });
}
