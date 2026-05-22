import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:waddle_backup/waddle_backup_service.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';
import '../helpers/rest_auth_helper.dart';

void main() {
  test('GET backup status', () async {
    final harness = await RestTestHarness.start();
    addTearDown(() => harness.dispose());

    final res = await http.get(
      Uri.parse('${harness.baseUrl}/v1/display/backup/status'),
      headers: harness.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['database_path'], isA<String>());
    expect(body['jobs_directory'], contains('backups'));
  });

  test('restore requires confirm=yes', () async {
    final harness = await RestTestHarness.start();
    addTearDown(() => harness.dispose());

    final res = await http.post(
      Uri.parse('${harness.baseUrl}/v1/display/backup/restore'),
      headers: harness.authHeaders,
      body: [1, 2, 3],
    );
    expect(res.statusCode, 400);
    expect(res.body, contains('confirm_required'));
  });

  test('backup job create poll download when file db available', () async {
    final tmp = Directory.systemTemp.createTempSync('waddle_bu_rest');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final dbFile = File(p.join(tmp.path, 'waddle_display.db'));
    AppDatabase? db;
    try {
      db = AppDatabase(createQueryExecutorForFile(dbFile));
      await warmDatabase(db);
    } catch (_) {
      // Native sqlite unavailable in this test runtime (e.g. some Windows hosts).
      return;
    }
    addTearDown(() async => db?.close());

    final harness = await RestTestHarness.start(
      database: db,
      supportDirectory: tmp,
      databaseFile: dbFile,
    );
    addTearDown(() => harness.dispose());

    final createRes = await http.post(
      Uri.parse('${harness.baseUrl}/v1/display/backup/jobs'),
      headers: harness.authHeaders,
    );
    expect(createRes.statusCode, 202);
    final createBody = jsonDecode(createRes.body) as Map<String, dynamic>;
    final jobId = createBody['job_id'] as String;

    Map<String, dynamic>? job;
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final poll = await http.get(
        Uri.parse('${harness.baseUrl}/v1/display/backup/jobs/$jobId'),
        headers: harness.authHeaders,
      );
      expect(poll.statusCode, 200);
      job = jsonDecode(poll.body) as Map<String, dynamic>;
      if (job['status'] == 'ready' || job['status'] == 'failed') {
        break;
      }
    }
    expect(job?['status'], 'ready');

    final dl = await http.get(
      Uri.parse('${harness.baseUrl}/v1/display/backup/jobs/$jobId/download'),
      headers: {'Authorization': harness.authHeaders['Authorization']!},
    );
    expect(dl.statusCode, 200);
    expect(dl.bodyBytes.length, greaterThan(50));
    final manifest = readManifestFromArchive(decodeWaddleBackupBytes(dl.bodyBytes));
    expect(manifest.includeDatabase, isTrue);
  });
}
