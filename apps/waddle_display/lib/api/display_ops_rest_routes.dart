import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/display_env.dart';
import 'display_platform_arch.dart';

const _jsonHeaders = {'content-type': 'application/json'};

enum DisplayUpgradeJobStatus { pending, running, succeeded, failed }

class DisplayUpgradeJobRecord {
  DisplayUpgradeJobRecord({
    required this.id,
    required this.status,
    required this.downloadUrl,
    required this.startedAtUtc,
    this.error,
    this.completedAtUtc,
  });

  final String id;
  DisplayUpgradeJobStatus status;
  final String downloadUrl;
  String? error;
  final DateTime startedAtUtc;
  DateTime? completedAtUtc;
}

final Map<String, DisplayUpgradeJobRecord> _upgradeJobs = {};

void registerDisplayOpsRestRoutes(
  Router r, {
  required Map<String, String> env,
}) {
  final upgradeScript = (env[kDisplayUpgradeScriptEnv] ?? '').trim().isNotEmpty
      ? (env[kDisplayUpgradeScriptEnv] ?? '').trim()
      : '/usr/local/bin/waddle-view-upgrade.sh';

  r.post('/v1/display/ops/upgrade', (Request req) async {
    if (!isPiUpgradeCapable(upgradeScriptPath: upgradeScript)) {
      return Response(
        403,
        body: jsonEncode({
          'error': 'upgrade_not_capable',
          'hint': 'Linux arm64 with $upgradeScript installed (see docs/pi/using-the-image.md)',
        }),
        headers: _jsonHeaders,
      );
    }
    final body = await req.readAsString();
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return Response(
          400,
          body: '{"error":"invalid_json_body"}',
          headers: _jsonHeaders,
        );
      }
      map = decoded;
    } on Object {
      return Response(
        400,
        body: '{"error":"invalid_json_body"}',
        headers: _jsonHeaders,
      );
    }
    final downloadUrl = map['download_url'] as String?;
    if (downloadUrl == null || downloadUrl.trim().isEmpty) {
      return Response(
        400,
        body: '{"error":"download_url_required"}',
        headers: _jsonHeaders,
      );
    }
    final parsed = Uri.tryParse(downloadUrl.trim());
    if (parsed == null ||
        (parsed.scheme != 'https' && parsed.scheme != 'http')) {
      return Response(
        400,
        body: '{"error":"invalid_download_url"}',
        headers: _jsonHeaders,
      );
    }
    final id = 'up_${DateTime.now().toUtc().millisecondsSinceEpoch}';
    final record = DisplayUpgradeJobRecord(
      id: id,
      status: DisplayUpgradeJobStatus.pending,
      downloadUrl: downloadUrl.trim(),
      startedAtUtc: DateTime.now().toUtc(),
    );
    _upgradeJobs[id] = record;
    unawaited(_runUpgrade(record, upgradeScript: upgradeScript, sha256: map['sha256'] as String?));
    return Response(
      202,
      body: jsonEncode({'job_id': id, 'status': 'pending'}),
      headers: _jsonHeaders,
    );
  });

  r.get('/v1/display/ops/upgrade/<id>', (Request req, String id) async {
    final job = _upgradeJobs[id];
    if (job == null) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: _jsonHeaders,
      );
    }
    return Response.ok(
      jsonEncode({
        'id': job.id,
        'status': job.status.name,
        'download_url': job.downloadUrl,
        if (job.error != null) 'error': job.error,
        'started_at_utc': job.startedAtUtc.toIso8601String(),
        if (job.completedAtUtc != null)
          'completed_at_utc': job.completedAtUtc!.toIso8601String(),
      }),
      headers: _jsonHeaders,
    );
  });
}

Future<void> _runUpgrade(
  DisplayUpgradeJobRecord record, {
  required String upgradeScript,
  String? sha256,
}) async {
  record.status = DisplayUpgradeJobStatus.running;
  try {
    final args = <String>['--download-url', record.downloadUrl];
    if (sha256 != null && sha256.trim().isNotEmpty) {
      args.addAll(['--sha256', sha256.trim()]);
    }
    final result = await Process.run(upgradeScript, args);
    if (result.exitCode != 0) {
      record.status = DisplayUpgradeJobStatus.failed;
      record.error = (result.stderr as String).trim().isNotEmpty
          ? '${result.stderr}'
          : 'exit ${result.exitCode}';
      record.completedAtUtc = DateTime.now().toUtc();
      return;
    }
    record.status = DisplayUpgradeJobStatus.succeeded;
    record.completedAtUtc = DateTime.now().toUtc();
    // Upgrade script stops systemd and replaces bundle; exit so a supervisor can restart.
    exit(0);
  } on Object catch (e) {
    record.status = DisplayUpgradeJobStatus.failed;
    record.error = e.toString();
    record.completedAtUtc = DateTime.now().toUtc();
  }
}
