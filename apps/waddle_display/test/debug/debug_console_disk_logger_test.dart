import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:waddle_display/debug/debug_console_disk_logger.dart';

void main() {
  tearDown(() async {
    DebugConsoleDiskLogger.setSupportDirectoryOverrideForTest(null);
    await DebugConsoleDiskLogger.closeForTest();
  });

  Future<File> singleLogFile(Directory tmp) async {
    final logsDir = Directory(p.join(tmp.path, 'debug_console_logs'));
    final files = logsDir.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    return files.single;
  }

  test('installForTest writes zone print after install', () async {
    final tmp = await Directory.systemTemp.createTemp('waddle_debug_log_test_');
    addTearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    await runZoned(
      () async {
        await DebugConsoleDiskLogger.installForTest(tmp);
        // ignore: avoid_print — exercising zone print interception
        print('after-install');
      },
      zoneSpecification: DebugConsoleDiskLogger.debugZoneSpecification(),
    );

    await DebugConsoleDiskLogger.closeForTest();

    final log = await singleLogFile(tmp);
    final text = await log.readAsString();
    expect(text, contains('after-install'));
  });

  test('zone print before install is buffered then flushed', () async {
    final tmp = await Directory.systemTemp.createTemp('waddle_debug_log_test_');
    addTearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    await runZoned(
      () async {
        // ignore: avoid_print
        print('early-line');
        await DebugConsoleDiskLogger.installForTestPreservingBufferedPrints(tmp);
      },
      zoneSpecification: DebugConsoleDiskLogger.debugZoneSpecification(),
    );

    await DebugConsoleDiskLogger.closeForTest();

    final log = await singleLogFile(tmp);
    expect(await log.readAsString(), contains('early-line'));
  });

  test('appendNamedLine appears in log after install', () async {
    final tmp = await Directory.systemTemp.createTemp('waddle_debug_log_test_');
    addTearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    await DebugConsoleDiskLogger.installForTest(tmp);
    DebugConsoleDiskLogger.appendNamedLine('TestChannel', 'hello');
    await DebugConsoleDiskLogger.closeForTest();

    final log = await singleLogFile(tmp);
    expect(await log.readAsString(), contains('[TestChannel] hello'));
  });

  test('appendMultiline writes each line', () async {
    final tmp = await Directory.systemTemp.createTemp('waddle_debug_log_test_');
    addTearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    await DebugConsoleDiskLogger.installForTest(tmp);
    DebugConsoleDiskLogger.appendMultiline('a\nb');
    await DebugConsoleDiskLogger.closeForTest();

    final log = await singleLogFile(tmp);
    final text = await log.readAsString();
    expect(text, contains('a'));
    expect(text, contains('b'));
  });

  test('appendMultiline empty is a no-op on content', () async {
    final tmp = await Directory.systemTemp.createTemp('waddle_debug_log_test_');
    addTearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    await DebugConsoleDiskLogger.installForTest(tmp);
    DebugConsoleDiskLogger.appendMultiline('');
    await DebugConsoleDiskLogger.closeForTest();

    final log = await singleLogFile(tmp);
    expect(await log.readAsString(), contains('Waddle View'));
  });

  test('debugPrint tee restores previous callback after close', () async {
    final tmp = await Directory.systemTemp.createTemp('waddle_debug_log_test_');
    addTearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    final previous = debugPrint;
    await DebugConsoleDiskLogger.installForTest(tmp);
    debugPrint('dp-line');
    await DebugConsoleDiskLogger.closeForTest();
    expect(identical(debugPrint, previous), isTrue);

    final log = await singleLogFile(tmp);
    expect(await log.readAsString(), contains('dp-line'));
  });

  test('debugPrint null message is logged as null line', () async {
    final tmp = await Directory.systemTemp.createTemp('waddle_debug_log_test_');
    addTearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    await DebugConsoleDiskLogger.installForTest(tmp);
    debugPrint(null);
    await DebugConsoleDiskLogger.closeForTest();

    final log = await singleLogFile(tmp);
    expect(await log.readAsString(), contains('null'));
  });

  test('utc file stamp replaces colon', () {
    final s = DebugConsoleDiskLogger.utcFileStampForTest(
      DateTime.utc(2026, 1, 2, 3, 4, 5, 6),
    );
    expect(s, isNot(contains(':')));
    expect(s, contains('2026-01-02'));
  });

  test('second install at same path while active is a no-op', () async {
    final tmp = await Directory.systemTemp.createTemp('waddle_debug_log_test_');
    addTearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    await DebugConsoleDiskLogger.installForTest(tmp);
    final path1 = DebugConsoleDiskLogger.currentLogFileForTest?.path;
    await DebugConsoleDiskLogger.installAtSupportPathWhileInstalledForTest(
      tmp.path,
    );
    expect(DebugConsoleDiskLogger.currentLogFileForTest?.path, path1);

    final logsDir = Directory(p.join(tmp.path, 'debug_console_logs'));
    expect(logsDir.listSync().whereType<File>().length, 1);

    await DebugConsoleDiskLogger.closeForTest();
  });

  test('install uses support directory override when set', () async {
    final tmp = await Directory.systemTemp.createTemp('waddle_support_override_');
    addTearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });
    DebugConsoleDiskLogger.setSupportDirectoryOverrideForTest(() async => tmp);
    await DebugConsoleDiskLogger.install();
    expect(DebugConsoleDiskLogger.currentLogFileForTest, isNotNull);
    expect(
      DebugConsoleDiskLogger.currentLogFileForTest!.path,
      contains('debug_console_'),
    );
    await DebugConsoleDiskLogger.closeForTest();
    await DebugConsoleDiskLogger.install();
  });

  test('install clears state when support directory getter throws', () async {
    DebugConsoleDiskLogger.setSupportDirectoryOverrideForTest(
      () async => throw StateError('no-dir'),
    );
    await DebugConsoleDiskLogger.install();
    expect(DebugConsoleDiskLogger.currentLogFileForTest, isNull);
  });
}
