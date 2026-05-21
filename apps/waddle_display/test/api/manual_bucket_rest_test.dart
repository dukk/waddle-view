import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/seed/initial_seed.dart';
import 'package:waddle_shared/seed/tables/interests_jokes_seed.dart';

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
