import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Release-safe append-only fatal log under app support (`fatal_logs/`).
final class FatalDiskLogger {
  FatalDiskLogger._();

  static IOSink? _sink;
  static File? _logFile;
  static Future<Directory> Function()? _supportDirectoryOverrideForTest;

  static Future<void> appendFatal(
    String channel,
    Object error,
    StackTrace? stack,
  ) async {
    try {
      await _ensureOpen();
      _writeLine('[Fatal.$channel] ${Error.safeToString(error)}');
      if (stack != null) {
        for (final line in stack.toString().split('\n')) {
          _writeLine(line);
        }
      }
      await _sink?.flush();
    } catch (_) {
      // Never let logging break fatal handling.
    }
  }

  static Future<void> _ensureOpen() async {
    if (_sink != null) {
      return;
    }
    final support = await _supportRootDirectory();
    final dir = Directory(p.join(support.path, 'fatal_logs'));
    await dir.create(recursive: true);
    final stamp = _utcFileStamp(DateTime.now().toUtc());
    _logFile = File(p.join(dir.path, 'fatal_$stamp.log'));
    _sink = _logFile!.openWrite(mode: FileMode.writeOnlyAppend);
    _sink!
      ..writeln('Waddle View — fatal log')
      ..writeln('Started (UTC): ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln();
  }

  static Future<Directory> _supportRootDirectory() async {
    final o = _supportDirectoryOverrideForTest;
    if (o != null) {
      return o();
    }
    return getApplicationSupportDirectory();
  }

  static void _writeLine(String line) {
    _sink?.writeln(line);
  }

  static String _utcFileStamp(DateTime utc) {
    return utc.toIso8601String().replaceAll(':', '-').replaceAll('+', '_');
  }

  @visibleForTesting
  static File? get currentLogFileForTest => _logFile;

  @visibleForTesting
  static void setSupportDirectoryOverrideForTest(
    Future<Directory> Function()? override,
  ) {
    _supportDirectoryOverrideForTest = override;
  }

  @visibleForTesting
  static Future<void> closeForTest() async {
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {
      // ignore
    } finally {
      _sink = null;
      _logFile = null;
    }
  }
}
