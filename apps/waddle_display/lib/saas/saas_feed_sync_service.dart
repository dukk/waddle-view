import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/database.dart';

/// Subscribes to SaaS SSE and applies feed deltas into local SQLite.
class SaasFeedSyncService {
  SaasFeedSyncService({
    required this.db,
    required this.apiBaseUrl,
    required this.displayId,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final AppDatabase db;
  final String apiBaseUrl;
  final String displayId;
  final String apiKey;
  final http.Client _client;

  bool _running = false;

  Future<void> start() async {
    _running = true;
    while (_running) {
      try {
        await _streamOnce();
      } on Object {
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    }
  }

  void stop() => _running = false;

  Future<void> _streamOnce() async {
    final uri = Uri.parse(
      '$apiBaseUrl/v1/displays/$displayId/feeds/stream',
    );
    final request = http.Request('GET', uri);
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['Accept'] = 'text/event-stream';
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw StateError('SSE status ${response.statusCode}');
    }
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      if (!_running) break;
      for (final line in chunk.split('\n')) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        await _applyEvent(payload);
      }
    }
  }

  Future<void> _applyEvent(String jsonLine) async {
    final decoded = jsonDecode(jsonLine);
    if (decoded is! Map) return;
    final kind = decoded['kind']?.toString();
    if (kind == null || !kind.startsWith('calendar.')) return;
    final items = decoded['items'];
    if (items is! List) return;
    for (final raw in items) {
      if (raw is! Map) continue;
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      final externalId = map['externalId']?.toString() ?? map['id']?.toString();
      final title = map['title']?.toString();
      if (externalId == null || title == null) continue;
      final start = _parseDate(map['startsAt']) ?? DateTime.now().toUtc();
      final end = _parseDate(map['endsAt']) ?? start.add(const Duration(hours: 1));
      final id = 'saas:$externalId';
      await db.into(db.calendarEvents).insertOnConflictUpdate(
            CalendarEventsCompanion(
              id: Value(id),
              title: Value(title),
              startMs: Value(start),
              endMs: Value(end),
              source: Value(map['source']?.toString() ?? 'saas'),
              externalId: Value(externalId),
              updatedAtMs: Value(DateTime.now().toUtc()),
            ),
          );
    }
  }

  DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
