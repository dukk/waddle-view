import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Debug-only capture of console-style output to a per-run log file under the
/// app support directory (`debug_console_logs/`).
///
/// Intercepts [Zone] `print`, tees [debugPrint] after [install], and accepts
/// explicit lines from [AppDebugLog] via [appendNamedLine] /
/// [appendMultiline].
final class DebugConsoleDiskLogger {
  DebugConsoleDiskLogger._();

  static IOSink? _sink;
  static DebugPrintCallback? _previousDebugPrint;
  static final List<String> _buffer = <String>[];
  static bool _installed = false;
  static File? _logFile;
  static Future<Directory> Function()? _supportDirectoryOverrideForTest;

  /// Pass to [runZonedGuarded] in debug builds so `print` is tee'd to disk.
  static ZoneSpecification debugZoneSpecification() {
    return ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        if (kDebugMode) {
          _enqueueLine(line);
        }
        parent.print(zone, line);
      },
    );
  }

  /// Opens a new timestamped log file under application support (debug only).
  static Future<void> install() async {
    if (!kDebugMode || _installed) {
      return;
    }
    try {
      final support = await _supportRootDirectory();
      await _installAtSupportPath(support.path);
    } catch (_) {
      _installed = false;
      await _sink?.close();
      _sink = null;
      _logFile = null;
    }
  }

  static Future<Directory> _supportRootDirectory() {
    final o = _supportDirectoryOverrideForTest;
    if (o != null) {
      return o();
    }
    return getApplicationSupportDirectory();
  }

  static Future<void> _installAtSupportPath(String supportPath) async {
    if (!kDebugMode || _installed) {
      return;
    }
    _installed = true;
    try {
      final dir = Directory(p.join(supportPath, 'debug_console_logs'));
      await dir.create(recursive: true);
      final stamp = _utcFileStamp(DateTime.now().toUtc());
      _logFile = File(p.join(dir.path, 'debug_console_$stamp.log'));
      _sink = _logFile!.openWrite(mode: FileMode.writeOnlyAppend);
      _sink!
        ..writeln('Waddle View — debug console log')
        ..writeln('Started (UTC): ${DateTime.now().toUtc().toIso8601String()}')
        ..writeln();
      for (final chunk in _buffer) {
        _sink!.write(chunk);
      }
      _buffer.clear();
      await _sink?.flush();
      _chainDebugPrint();
    } catch (_) {
      _installed = false;
      await _sink?.close();
      _sink = null;
      _logFile = null;
    }
  }

  static void _chainDebugPrint() {
    _previousDebugPrint = debugPrint;
    final previous = _previousDebugPrint!;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (kDebugMode) {
        if (message == null) {
          _enqueueLine('null');
        } else {
          for (final line in message.split('\n')) {
            _enqueueLine(line);
          }
        }
      }
      previous(message, wrapWidth: wrapWidth);
    };
  }

  /// Optional channel line (mirrors `developer.log` name + message in IDE).
  static void appendNamedLine(String name, String message) {
    if (!kDebugMode) {
      return;
    }
    _enqueueLine('[$name] $message');
  }

  /// Multi-line block (stack traces, stderr-style blocks).
  static void appendMultiline(String text) {
    if (!kDebugMode || text.isEmpty) {
      return;
    }
    for (final line in text.split('\n')) {
      _enqueueLine(line);
    }
  }

  static void _enqueueLine(String line) {
    try {
      final chunk = '$line\n';
      final s = _sink;
      if (s != null) {
        s.write(chunk);
      } else {
        _buffer.add(chunk);
      }
    } catch (_) {
      // Never let logging break the app.
    }
  }

  static String _utcFileStamp(DateTime utc) {
    return utc
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('+', '_');
  }

  /// Flushes and closes the log; restores [debugPrint]. Safe to call twice.
  static Future<void> close() async {
    if (_previousDebugPrint != null) {
      debugPrint = _previousDebugPrint!;
      _previousDebugPrint = null;
    }
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {
      // ignore
    } finally {
      _sink = null;
      _logFile = null;
      _installed = false;
    }
  }

  // --- Test hooks ---

  @visibleForTesting
  static File? get currentLogFileForTest => _logFile;

  @visibleForTesting
  static void setSupportDirectoryOverrideForTest(
    Future<Directory> Function()? override,
  ) {
    _supportDirectoryOverrideForTest = override;
  }

  @visibleForTesting
  static String utcFileStampForTest(DateTime utc) => _utcFileStamp(utc);

  @visibleForTesting
  static Future<void> installForTest(Directory parent) async {
    if (!kDebugMode) {
      return;
    }
    await closeForTest();
    await _installAtSupportPath(parent.path);
  }

  /// Like [installForTest] but does not clear the print buffer before opening
  /// the file (for tests that `print` before install within the same zone).
  @visibleForTesting
  static Future<void> installForTestPreservingBufferedPrints(
    Directory parent,
  ) async {
    if (!kDebugMode) {
      return;
    }
    await close();
    await _installAtSupportPath(parent.path);
  }

  /// Calls [_installAtSupportPath] while a session is already active (no-op).
  @visibleForTesting
  static Future<void> installAtSupportPathWhileInstalledForTest(
    String supportPath,
  ) async {
    await _installAtSupportPath(supportPath);
  }

  @visibleForTesting
  static Future<void> closeForTest() async {
    await close();
    _buffer.clear();
  }
}
