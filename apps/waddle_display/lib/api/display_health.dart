import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

/// Application version (keep in sync with [pubspec.yaml] `version` before `+`).
const kWaddleDisplayAppVersion = '1.0.0';

/// Build number (keep in sync with [pubspec.yaml] `version` after `+`).
const kWaddleDisplayBuildNumber = '1';

/// Host facts exposed on `GET /v1/health` (overridable in tests).
@immutable
class DisplayHostFacts {
  const DisplayHostFacts({
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.localHostname,
    required this.numberOfProcessors,
    required this.dartVersion,
  });

  final String operatingSystem;
  final String operatingSystemVersion;
  final String localHostname;
  final int numberOfProcessors;
  final String dartVersion;

  factory DisplayHostFacts.fromPlatform() {
    if (kIsWeb) {
      return const DisplayHostFacts(
        operatingSystem: 'web',
        operatingSystemVersion: '',
        localHostname: '',
        numberOfProcessors: 0,
        dartVersion: '',
      );
    }
    return DisplayHostFacts(
      operatingSystem: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
      localHostname: Platform.localHostname,
      numberOfProcessors: Platform.numberOfProcessors,
      dartVersion: Platform.version.split('\n').first,
    );
  }
}

/// JSON body for `GET /v1/health`.
Map<String, dynamic> buildDisplayHealthJson({
  required int schemaVersion,
  DisplayHostFacts? hostFacts,
  DateTime? serverStartedAt,
  DateTime? now,
}) {
  final host = hostFacts ?? DisplayHostFacts.fromPlatform();
  final clock = (now ?? DateTime.now()).toUtc();
  final started = serverStartedAt?.toUtc();
  final uptimeSeconds = started == null
      ? null
      : clock.difference(started).inSeconds.clamp(0, 1 << 31);

  return {
    'status': 'ok',
    'app': 'waddle_display',
    'version': kWaddleDisplayAppVersion,
    'build': kWaddleDisplayBuildNumber,
    'schema_version': schemaVersion,
    'platform_os': host.operatingSystem,
    if (host.operatingSystemVersion.isNotEmpty)
      'platform_os_version': host.operatingSystemVersion,
    if (host.localHostname.isNotEmpty) 'hostname': host.localHostname,
    'cpu_count': host.numberOfProcessors,
    if (host.dartVersion.isNotEmpty) 'dart_version': host.dartVersion,
    if (uptimeSeconds != null) 'uptime_seconds': uptimeSeconds,
  };
}

String encodeDisplayHealthJson({
  required int schemaVersion,
  DisplayHostFacts? hostFacts,
  DateTime? serverStartedAt,
  DateTime? now,
}) =>
    jsonEncode(
      buildDisplayHealthJson(
        schemaVersion: schemaVersion,
        hostFacts: hostFacts,
        serverStartedAt: serverStartedAt,
        now: now,
      ),
    );
